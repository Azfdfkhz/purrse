import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/category_model.dart';
import '../models/expense_model.dart';
import 'storage_service.dart';
import 'supabase_service.dart';

enum SyncStatus { idle, syncing, offline, error, notLinked }

/// Sinkronisasi dua arah lokal <-> Supabase untuk pengguna yang akunnya
/// terhubung ke Supabase Auth (ID lokal == auth.uid()).
///
/// - Pull dulu, baru push: versi cloud yang lebih baru tidak tertimpa.
/// - Konflik: last-write-wins per baris berdasarkan updated_at.
/// - Kursor pull memakai server_ts (jam server), bukan jam perangkat, sehingga
///   perangkat dengan jam salah tidak membuat data terlewat.
/// - Hapus = tombstone (deleted_at), ikut tersinkron.
/// - Foto bukti tetap di Google Drive; yang disinkronkan hanya drive_file_id.
class SyncService extends ChangeNotifier {
  SyncService._();
  static final SyncService instance = SyncService._();

  static const _pageSize = 500;
  static const _pushChunk = 200;

  SyncStatus status = SyncStatus.idle;
  String? lastError;
  DateTime? lastSyncedAt;

  /// Naik setiap kali pull mengubah data lokal; layar memuat ulang saat berubah.
  int dataRevision = 0;

  Timer? _debounce;
  Timer? _periodic;
  bool _running = false;
  bool _again = false;

  /// Mulai sinkronisasi berkala (panggil saat pengguna sudah masuk).
  void start() {
    _periodic?.cancel();
    _periodic = Timer.periodic(const Duration(minutes: 3), (_) => syncNow());
    markDirty(delay: const Duration(seconds: 1));
  }

  void stop() {
    _debounce?.cancel();
    _periodic?.cancel();
    _debounce = null;
    _periodic = null;
    status = SyncStatus.idle;
    lastError = null;
    notifyListeners();
  }

  /// Ada perubahan lokal: kirim setelah jeda singkat (banyak perubahan = satu sync).
  void markDirty({Duration delay = const Duration(seconds: 5)}) {
    if (!SupabaseService.instance.isSignedIn) return;
    _debounce?.cancel();
    _debounce = Timer(delay, syncNow);
  }

  void _set(SyncStatus s, [String? error]) {
    status = s;
    lastError = error;
    notifyListeners();
  }

  /// Sinkronkan sekarang. Mengembalikan true bila selesai tanpa error.
  Future<bool> syncNow() async {
    if (_running) {
      _again = true;
      return false;
    }
    final supa = SupabaseService.instance;
    final client = supa.client;
    final authUser = supa.currentUser;
    if (client == null || authUser == null) {
      _set(SyncStatus.notLinked);
      return false;
    }
    final local = await StorageService.instance.getCurrentUser();
    if (local == null || local.id != authUser.id) {
      // Akun lokal belum terhubung ke akun cloud ini.
      _set(SyncStatus.notLinked);
      return false;
    }

    _running = true;
    _set(SyncStatus.syncing);
    var ok = false;
    try {
      final uid = authUser.id;
      await StorageService.instance.stampLegacyCategories(uid);
      await _pull(client, uid);
      await _push(client, uid);
      lastSyncedAt = DateTime.now();
      _set(SyncStatus.idle);
      ok = true;
    } catch (e) {
      final text = e.toString();
      final offline = text.contains('SocketException') ||
          text.contains('ClientException') ||
          text.contains('Failed host lookup') ||
          text.contains('TimeoutException') ||
          text.contains('AuthRetryableFetchException');
      debugPrint('Sinkronisasi gagal: $e');
      _set(offline ? SyncStatus.offline : SyncStatus.error, offline ? null : text);
    } finally {
      _running = false;
      if (_again) {
        _again = false;
        unawaited(syncNow());
      }
    }
    return ok;
  }

  // ------------------------------------------------------------------ PULL

  Future<void> _pull(dynamic client, String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final cursorKey = 'sync_cursor_$uid';
    final cursor = prefs.getString(cursorKey);
    final full = cursor == null;

    String? maxTs = cursor;
    DateTime? maxParsed = cursor == null ? null : DateTime.tryParse(cursor);
    void track(Map r) {
      final raw = r['server_ts']?.toString();
      final t = raw == null ? null : DateTime.tryParse(raw);
      if (raw != null && t != null && (maxParsed == null || t.isAfter(maxParsed!))) {
        maxParsed = t;
        maxTs = raw;
      }
    }

    Future<List<Map<String, dynamic>>> fetchAll(String table) async {
      final out = <Map<String, dynamic>>[];
      var from = 0;
      while (true) {
        var q = client.from(table).select().eq('user_id', uid);
        if (cursor != null) q = q.gte('server_ts', cursor);
        final List page = await q
            .order('server_ts', ascending: true)
            .order('id', ascending: true)
            .range(from, from + _pageSize - 1);
        for (final r in page) {
          final m = Map<String, dynamic>.from(r as Map);
          track(m);
          out.add(m);
        }
        if (page.length < _pageSize) break;
        from += _pageSize;
      }
      return out;
    }

    final catRows = await fetchAll('categories');
    final expRows = await fetchAll('expenses');

    final changed = await StorageService.instance.mergeRemote(
      uid,
      categories: [for (final r in catRows) _categoryFromRow(r)],
      expenses: [for (final r in expRows) _expenseFromRow(r, uid)],
      fullPull: full,
    );
    if (maxTs != null) await prefs.setString(cursorKey, maxTs!);
    // fullPull menghapus kategori kembar lokal -> data lokal berubah walau
    // tidak ada baris baru; mergeRemote melaporkannya lewat `changed`.
    if (changed) {
      dataRevision++;
      notifyListeners();
    }
  }

  CategoryModel _categoryFromRow(Map<String, dynamic> r) => CategoryModel(
        id: r['id'] as String,
        name: r['name'] as String,
        color: Color((r['color'] as num).toInt()),
        icon: IconData(
          (r['icon_code'] as num).toInt(),
          fontFamily: (r['icon_font'] as String?) ?? 'MaterialIcons',
        ),
        updatedAt: DateTime.parse(r['updated_at'].toString()).toUtc(),
        deletedAt: r['deleted_at'] == null
            ? null
            : DateTime.parse(r['deleted_at'].toString()).toUtc(),
      );

  ExpenseModel _expenseFromRow(Map<String, dynamic> r, String uid) {
    final drive = r['drive_file_id'] as String?;
    return ExpenseModel(
      id: r['id'] as String,
      userId: uid,
      categoryId: r['category_id'] as String,
      amount: (r['amount_rupiah'] as num).toDouble(),
      date: ExpenseModel.parseDate(r['spent_on'].toString()),
      description: (r['description'] as String?) ?? '',
      createdAt: DateTime.parse(r['created_at'].toString()).toUtc(),
      updatedAt: DateTime.parse(r['updated_at'].toString()).toUtc(),
      deletedAt: r['deleted_at'] == null
          ? null
          : DateTime.parse(r['deleted_at'].toString()).toUtc(),
      syncState: SyncState.synced,
      driveFileId: drive,
      uploadStatus: drive != null ? UploadStatus.uploaded : UploadStatus.none,
    );
  }

  // ------------------------------------------------------------------ PUSH

  Future<void> _push(dynamic client, String uid) async {
    final storage = StorageService.instance;
    final prefs = await SharedPreferences.getInstance();

    // Kategori dulu (transaksi merujuk kategori). Kirim hanya bila berubah.
    final cats = await storage.getAllCategoriesRaw(uid);
    final catRows = [
      for (final c in cats)
        {
          'id': c.id,
          'user_id': uid,
          'name': c.name,
          'color': c.color.toARGB32(),
          'icon_code': c.icon.codePoint,
          'icon_font': c.icon.fontFamily,
          'updated_at': (c.updatedAt ?? DateTime.now().toUtc()).toIso8601String(),
          'deleted_at': c.deletedAt?.toIso8601String(),
        }
    ];
    final catHash = jsonEncode(catRows);
    final hashKey = 'sync_cat_hash_$uid';
    if (catRows.isNotEmpty && prefs.getString(hashKey) != catHash) {
      await client.from('categories').upsert(catRows, onConflict: 'id');
      await prefs.setString(hashKey, catHash);
    }

    // Transaksi yang belum tersinkron (termasuk tombstone).
    final pending = (await storage.getAllExpensesRaw(uid))
        .where((e) => e.syncState != SyncState.synced)
        .toList();
    for (var i = 0; i < pending.length; i += _pushChunk) {
      final chunk = pending.skip(i).take(_pushChunk).toList();
      final sent = <String, DateTime>{};
      try {
        await client.from('expenses').upsert(
          [for (final e in chunk) _expenseRow(e, uid)],
          onConflict: 'id',
        );
        for (final e in chunk) {
          sent[e.id] = e.updatedAt;
        }
      } catch (e) {
        if (chunk.length == 1) rethrow;
        // Satu baris bermasalah tidak boleh menahan yang lain: kirim satu-satu.
        Object? firstError;
        for (final row in chunk) {
          try {
            await client.from('expenses').upsert(_expenseRow(row, uid), onConflict: 'id');
            sent[row.id] = row.updatedAt;
          } catch (inner) {
            firstError ??= inner;
            debugPrint('Transaksi ${row.id} gagal dikirim: $inner');
          }
        }
        if (sent.isEmpty && firstError != null) throw firstError;
      }
      await storage.markExpensesSynced(uid, sent);
    }
  }

  Map<String, dynamic> _expenseRow(ExpenseModel e, String uid) => {
        'id': e.id,
        'user_id': uid,
        'category_id': e.categoryId,
        'amount_rupiah': e.amount.round() < 0 ? 0 : e.amount.round(),
        'spent_on': ExpenseModel.dateKey(e.date),
        'description': e.description,
        'drive_file_id': e.driveFileId,
        'created_at': e.createdAt.toUtc().toIso8601String(),
        'updated_at': e.updatedAt.toUtc().toIso8601String(),
        'deleted_at': e.deletedAt?.toUtc().toIso8601String(),
      };
}
