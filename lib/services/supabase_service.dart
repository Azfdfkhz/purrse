import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  // ============================================================
  // CONFIGURATION
  // Ganti URL dan Anon Key sesuai dengan Project Supabase Anda.
  // ============================================================
  static const String supabaseUrl = 'https://gkbcjseelrhmkjadbboj.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_SBoRhcSsI3ICTXbzkdRJQg_bvSCkdo6';

  bool _initialized = false;

  bool get isConfigured {
    return supabaseUrl.startsWith('https://') &&
        !supabaseUrl.contains('YOUR_PROJECT_ID') &&
        !supabaseAnonKey.contains('YOUR_SUPABASE_ANON_KEY');
  }

  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (!isConfigured) {
      debugPrint('Supabase: Credentials belum diisi di SupabaseService.');
      return;
    }

    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
      _initialized = true;
      debugPrint('Supabase: Berhasil diinisialisasi.');
    } catch (e) {
      debugPrint('Supabase: Gagal inisialisasi: $e');
    }
  }

  SupabaseClient? get client {
    if (!_initialized) return null;
    return Supabase.instance.client;
  }

  User? get currentUser => client?.auth.currentUser;
  Session? get currentSession => client?.auth.currentSession;
  bool get isSignedIn => currentUser != null;

  // ============================================================
  // AUTHENTICATION
  // ============================================================

  /// Registrasi pengguna baru ke Supabase Auth.
  Future<String?> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    if (!_initialized || client == null) {
      return null; // Local-only fallback
    }

    try {
      final res = await client!.auth.signUp(
        email: email,
        password: password,
        data: {'username': username},
      );

      if (res.user == null) {
        return 'Gagal membuat akun Supabase.';
      }
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Terjadi kesalahan Supabase Auth: $e';
    }
  }

  /// Login pengguna ke Supabase Auth.
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    if (!_initialized || client == null) {
      return null; // Local-only fallback
    }

    try {
      final res = await client!.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (res.user == null) {
        return 'Email atau password salah di Supabase.';
      }
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Terjadi kesalahan Supabase Auth: $e';
    }
  }

  /// Kirim email reset password jika pengguna lupa password.
  Future<String?> sendPasswordResetEmail(String email) async {
    if (!_initialized || client == null) {
      return 'Supabase belum dikonfigurasi. Silakan masukkan URL & Anon Key di SupabaseService.';
    }

    try {
      await client!.auth.resetPasswordForEmail(email.trim());
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Gagal mengirim email reset password: $e';
    }
  }

  /// Logout dari Supabase Auth.
  Future<void> signOut() async {
    if (!_initialized || client == null) return;
    try {
      await client!.auth.signOut();
    } catch (e) {
      debugPrint('Supabase signOut error: $e');
    }
  }

  // ============================================================
  // CLOUD BACKUP & SYNC
  // Table: public.user_backups
  // ============================================================

  /// Mengunggah / memperbarui backup data JSON ke tabel user_backups di Supabase.
  Future<void> uploadBackupToCloud(String backupJson) async {
    if (!_initialized || client == null || currentUser == null) return;

    try {
      final decoded = jsonDecode(backupJson);
      await client!.from('user_backups').upsert(
        {
          'user_id': currentUser!.id,
          'email': currentUser!.email ?? '',
          'backup_data': decoded,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'user_id',
      );
      debugPrint('Supabase: Auto-backup ke Cloud berhasil.');
    } catch (e) {
      debugPrint('Supabase: Gagal upload backup: $e');
    }
  }

  /// Mengunduh backup data JSON milik pengguna yang sedang login dari Supabase.
  Future<String?> fetchBackupFromCloud() async {
    if (!_initialized || client == null || currentUser == null) return null;

    try {
      final response = await client!
          .from('user_backups')
          .select('backup_data')
          .eq('user_id', currentUser!.id)
          .maybeSingle();

      if (response == null || response['backup_data'] == null) {
        return null;
      }

      return jsonEncode(response['backup_data']);
    } catch (e) {
      debugPrint('Supabase: Gagal download backup: $e');
      return null;
    }
  }
}
