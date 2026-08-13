import 'dart:convert';
import 'dart:typed_data';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

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
  }

  // ============================================================
  // LOGIN GOOGLE
  // ============================================================

  Future<GoogleSignInAccount?> signIn() async {
    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw Exception(
        'Google Sign-In tidak didukung pada perangkat ini.',
      );
    }

    final account =
    await GoogleSignIn.instance.authenticate();

    _account = account;

    return account;
  }

  // ============================================================
  // LOGOUT GOOGLE
  // ============================================================

  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();

    _account = null;
  }

  // ============================================================
  // GET CURRENT GOOGLE ACCOUNT
  // ============================================================

  GoogleSignInAccount? get account => _account;

  bool get isSignedIn => _account != null;

  // ============================================================
  // ACCESS TOKEN
  // ============================================================

  Future<String> getAccessToken() async {
    if (_account == null) {
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
  // CHECK BACKUP
  // ============================================================

  Future<bool> hasBackup() async {
    final fileId =
    await findBackupFile();

    return fileId != null;
  }
}