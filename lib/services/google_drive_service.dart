import 'dart:convert';
import 'dart:typed_data';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Dilempar saat Drive belum terhubung / izin kedaluwarsa / dicabut.
/// Pengguna perlu menghubungkan ulang secara manual.
class DriveAuthRequired implements Exception {
  final String message;
  const DriveAuthRequired([this.message = 'Google Drive perlu dihubungkan ulang.']);
  @override
  String toString() => message;
}

class GoogleDriveService {
  GoogleDriveService._();

  static final GoogleDriveService instance =
  GoogleDriveService._();

  static const String driveScope =
      'https://www.googleapis.com/auth/drive.file';

  static const String backupFileName =
      'Purrse_Backup.json';

  static const String driveFilesUrl =
      'https://www.googleapis.com/drive/v3/files';

  static const String driveUploadUrl =
      'https://www.googleapis.com/upload/drive/v3/files';

  GoogleSignInAccount? _account;

  // ============================================================
  // INITIALIZE
  // ============================================================

  static const String serverClientId =
      '620421235824-t3gmiq05jlm21r972oammtjp6aqnrbtl.apps.googleusercontent.com';

  Future<void> initialize() async {
    await GoogleSignIn.instance.initialize(
      serverClientId: serverClientId,
    );
    GoogleSignIn.instance.authenticationEvents.listen((event) {
      if (event is GoogleSignInAuthenticationEventSignIn) {
        _remember(event.user);
      } else if (event is GoogleSignInAuthenticationEventSignOut) {
        _forget();
      }
    });

    // Muat status "pernah terhubung" lebih dulu supaya UI tidak sempat
    // menampilkan "Hubungkan" sebelum sesi selesai dipulihkan.
    final prefs = await SharedPreferences.getInstance();
    _persistedConnected = prefs.getBool(_kConnectedFlag) ?? false;
    _persistedEmail = prefs.getString(_kEmail);
  }

  // ============================================================
  // STATUS TERSIMPAN (satu kali hubungkan -> menetap)
  // ============================================================

  static const String _kConnectedFlag = 'drive_connected';
  static const String _kEmail = 'drive_email';

  bool _persistedConnected = false;
  String? _persistedEmail;

  /// True bila pengguna pernah menghubungkan Drive dan belum memutusnya,
  /// walaupun sesi Google belum selesai dipulihkan pada peluncuran ini.
  bool get isLinked => _persistedConnected;

  /// Email akun Drive (dari sesi aktif, atau yang tersimpan terakhir).
  String? get linkedEmail => _account?.email ?? _persistedEmail;

  /// Simpan akun Google yang terautentikasi (misal dari login Google aplikasi).
  Future<void> setAccount(GoogleSignInAccount account) => _remember(account);

  Future<void> _remember(GoogleSignInAccount account) async {
    _account = account;
    _persistedConnected = true;
    _persistedEmail = account.email;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kConnectedFlag, true);
    await prefs.setString(_kEmail, account.email);
  }

  Future<void> _forget() async {
    _account = null;
    _persistedConnected = false;
    _persistedEmail = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kConnectedFlag, false);
    await prefs.remove(_kEmail);
  }

  /// True jika pengguna pernah menghubungkan Drive dan belum memutusnya.
  Future<bool> wasConnected() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kConnectedFlag) ?? false;
  }

  // ============================================================
  // LOGIN GOOGLE (interaktif, hanya sekali)
  // ============================================================

  Future<GoogleSignInAccount?> signIn() async {
    // Jangan munculkan pemilih akun lagi bila akun Drive sebelumnya masih
    // tersimpan dan dapat dipulihkan secara senyap.
    if (_account != null) return _account;
    if (await restoreSession()) return _account;
    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw Exception(
        'Google Sign-In tidak didukung pada perangkat ini.',
      );
    }

    // Minta izin Drive bersamaan dengan login, supaya persetujuan hanya
    // muncul satu kali dan tidak diminta lagi saat backup.
    final account = await GoogleSignIn.instance.authenticate(
      scopeHint: [driveScope],
    );

    final client = account.authorizationClient;
    final granted = await client.authorizationForScopes([driveScope]);
    if (granted == null) {
      await client.authorizeScopes([driveScope]);
    }

    await _remember(account);
    return account;
  }

  // ============================================================
  // PULIHKAN SESI SECARA SENYAP
  // ============================================================

  Future<bool>? _restoring;

  /// Pulihkan sesi tanpa dialog berulang.
  Future<bool> restoreSession() {
    if (_account != null) return Future.value(true);
    return _restoring ??= _doRestore().whenComplete(() => _restoring = null);
  }

  Future<bool> _doRestore() async {
    if (!await wasConnected()) return false;
    try {
      final pending = GoogleSignIn.instance.attemptLightweightAuthentication();
      final account = pending == null ? null : await pending;
      if (account != null) {
        await _remember(account);
        return true;
      }
    } catch (_) {
      // gagal pulihkan senyap; jangan hapus status terhubung
    }
    return false;
  }

  /// Pastikan ada sesi: pulihkan dulu, baru (bila perlu) tampilkan login.
  Future<bool> ensureConnected({bool interactive = true}) async {
    if (_account != null) return true;
    if (await restoreSession()) return true;
    if (!interactive) return false;
    return (await signIn()) != null;
  }

  // ============================================================
  // LOGOUT GOOGLE (hanya atas permintaan pengguna)
  // ============================================================

  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } finally {
      await _forget();
    }
  }

  // ============================================================
  // GET CURRENT GOOGLE ACCOUNT
  // ============================================================

  GoogleSignInAccount? get account => _account;

  bool get isSignedIn => _account != null;

  // ============================================================
  // ACCESS TOKEN
  // ============================================================

  Future<String> getAccessToken({bool interactive = true}) async {
    if (_account == null && !await restoreSession()) {
      if (!interactive) throw DriveAuthRequired();
      await signIn();
    }

    if (_account == null) {
      throw Exception(
        'Akun Google belum terhubung.',
      );
    }

    final authorization =
    await _account!.authorizationClient
        .authorizationForScopes(
      [driveScope],
    );

    if (authorization != null) {
      return authorization.accessToken;
    }

    // Tanpa dialog: jangan membuka layar izin dari proses latar belakang.
    if (!interactive) throw DriveAuthRequired();

    final newAuthorization =
    await _account!.authorizationClient
        .authorizeScopes(
      [driveScope],
    );

    return newAuthorization.accessToken;
  }

  // ============================================================
  // FIND BACKUP
  // ============================================================

  Future<String?> findBackupFile() async {
    final token = await getAccessToken();

    final query =
        "name = '$backupFileName' "
        "and trashed = false";

    final uri = Uri.parse(
      driveFilesUrl,
    ).replace(
      queryParameters: {
        'q': query,
        'spaces': 'drive',
        'fields':
        'files(id,name,modifiedTime,size)',
        'pageSize': '10',
      },
    );

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Gagal mencari backup: ${response.body}',
      );
    }

    final data =
    jsonDecode(response.body)
    as Map<String, dynamic>;

    final files =
        data['files'] as List? ?? [];

    if (files.isEmpty) {
      return null;
    }

    return files.first['id']?.toString();
  }

  // ============================================================
  // CREATE BACKUP FILE
  // ============================================================

  Future<String> _createBackupFile(
      String backupJson,
      ) async {
    final token = await getAccessToken();

    final boundary =
        'purrse_boundary_${DateTime.now().millisecondsSinceEpoch}';

    final metadata = jsonEncode({
      'name': backupFileName,
      'mimeType': 'application/json',
    });

    final body = <int>[];

    body.addAll(
      utf8.encode(
        '--$boundary\r\n'
            'Content-Type: application/json; charset=UTF-8\r\n'
            '\r\n'
            '$metadata\r\n'
            '--$boundary\r\n'
            'Content-Type: application/json; charset=UTF-8\r\n'
            '\r\n',
      ),
    );

    body.addAll(
      utf8.encode(backupJson),
    );

    body.addAll(
      utf8.encode(
        '\r\n--$boundary--',
      ),
    );

    final response = await http.post(
      Uri.parse(
        '$driveUploadUrl?uploadType=multipart',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type':
        'multipart/related; boundary=$boundary',
      },
      body: Uint8List.fromList(body),
    );

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw Exception(
        'Gagal membuat backup: ${response.body}',
      );
    }

    final data =
    jsonDecode(response.body)
    as Map<String, dynamic>;

    return data['id'].toString();
  }

  // ============================================================
  // UPDATE BACKUP FILE
  // ============================================================

  Future<void> _updateBackupFile(
      String fileId,
      String backupJson,
      ) async {
    final token = await getAccessToken();

    final response = await http.patch(
      Uri.parse(
        '$driveUploadUrl/$fileId?uploadType=media',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type':
        'application/json; charset=UTF-8',
      },
      body: backupJson,
    );

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw Exception(
        'Gagal memperbarui backup: ${response.body}',
      );
    }
  }

  // ============================================================
  // BACKUP
  // ============================================================

  Future<void> uploadOrUpdateBackup(
      String backupJson,
      ) async {
    final fileId =
    await findBackupFile();

    if (fileId == null) {
      await _createBackupFile(
        backupJson,
      );
    } else {
      await _updateBackupFile(
        fileId,
        backupJson,
      );
    }
  }

  // ============================================================
  // DOWNLOAD BACKUP
  // ============================================================

  Future<String> downloadBackup() async {
    final token = await getAccessToken();

    final fileId =
    await findBackupFile();

    if (fileId == null) {
      throw Exception(
        'Backup Purrse belum ditemukan di Google Drive.',
      );
    }

    final uri = Uri.parse(
      '$driveFilesUrl/$fileId',
    ).replace(
      queryParameters: {
        'alt': 'media',
      },
    );

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Gagal mengunduh backup: ${response.body}',
      );
    }

    return response.body;
  }

  // ============================================================
  // FOTO BUKTI TRANSAKSI
  // ============================================================

  static const String proofIdProperty = 'purrseExpenseId';

  void _checkAuth(http.Response r) {
    if (r.statusCode == 401 || r.statusCode == 403) {
      throw DriveAuthRequired(
        'Izin Google Drive kedaluwarsa atau dicabut. Hubungkan ulang di Pengaturan.',
      );
    }
  }

  String _mimeFor(String path) {
    final p = path.toLowerCase();
    if (p.endsWith('.png')) return 'image/png';
    if (p.endsWith('.webp')) return 'image/webp';
    if (p.endsWith('.gif')) return 'image/gif';
    if (p.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }

  /// Cari file bukti yang sudah ada untuk transaksi ini (anti duplikat).
  Future<String?> findProofFile(String expenseId, {required String token}) async {
    final uri = Uri.parse(driveFilesUrl).replace(queryParameters: {
      'q': "appProperties has { key='$proofIdProperty' and value='$expenseId' } "
          'and trashed = false',
      'spaces': 'drive',
      'fields': 'files(id)',
      'pageSize': '1',
    });
    final r = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
    _checkAuth(r);
    if (r.statusCode != 200) {
      throw Exception('Gagal memeriksa file bukti: ${r.statusCode}');
    }
    final files = (jsonDecode(r.body) as Map<String, dynamic>)['files'] as List? ?? [];
    return files.isEmpty ? null : files.first['id']?.toString();
  }

  /// Unggah foto bukti. Idempoten: jika sudah ada file dengan ID transaksi
  /// yang sama di Drive, ID file itu yang dikembalikan (tidak diunggah ulang).
  /// File bersifat pribadi (tidak dibagikan lewat tautan publik).
  /// Berhasil HANYA jika Drive mengembalikan ID file.
  Future<String> uploadProof({
    required String expenseId,
    required Uint8List bytes,
    required String localPath,
  }) async {
    final token = await getAccessToken(interactive: false);

    final existing = await findProofFile(expenseId, token: token);
    if (existing != null) return existing;

    final boundary = 'purrse_proof_${DateTime.now().millisecondsSinceEpoch}';
    final metadata = jsonEncode({
      'name': 'purrse_bukti_$expenseId.${localPath.split('.').last.toLowerCase()}',
      'appProperties': {proofIdProperty: expenseId},
    });

    final body = <int>[
      ...utf8.encode('--$boundary\r\n'
          'Content-Type: application/json; charset=UTF-8\r\n\r\n'
          '$metadata\r\n'
          '--$boundary\r\n'
          'Content-Type: ${_mimeFor(localPath)}\r\n\r\n'),
      ...bytes,
      ...utf8.encode('\r\n--$boundary--'),
    ];

    final r = await http.post(
      Uri.parse('$driveUploadUrl?uploadType=multipart&fields=id'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'multipart/related; boundary=$boundary',
      },
      body: Uint8List.fromList(body),
    );
    _checkAuth(r);
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception('Upload ditolak Drive (${r.statusCode}).');
    }
    final id = (jsonDecode(r.body) as Map<String, dynamic>)['id']?.toString();
    if (id == null || id.isEmpty) {
      throw Exception('Drive tidak mengonfirmasi ID file.');
    }
    return id;
  }

  /// Unduh foto bukti dari Drive (mis. di perangkat lain).
  Future<Uint8List> downloadProof(String fileId) async {
    final token = await getAccessToken(interactive: false);
    final r = await http.get(
      Uri.parse('$driveFilesUrl/$fileId').replace(queryParameters: {'alt': 'media'}),
      headers: {'Authorization': 'Bearer $token'},
    );
    _checkAuth(r);
    if (r.statusCode != 200) {
      throw Exception('Gagal mengunduh foto (${r.statusCode}).');
    }
    return r.bodyBytes;
  }

  // ============================================================
  // CHECK BACKUP
  // ============================================================

  Future<bool> hasBackup() async {
    final fileId =
    await findBackupFile();

    return fileId != null;
  }
}