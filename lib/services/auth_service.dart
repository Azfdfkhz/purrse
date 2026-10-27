import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import 'fcm_service.dart';
import 'google_drive_service.dart';
import 'storage_service.dart';
import 'supabase_service.dart';
import 'sync_service.dart';

/// Hasil login/daftar.
/// - [error]  : gagal, jangan lanjut.
/// - [info]   : tidak error tetapi belum bisa lanjut (mis. perlu konfirmasi email).
/// - [notice] : berhasil masuk, tampilkan pesan singkat setelahnya.
class AuthResult {
  final String? error;
  final String? info;
  final String? notice;
  const AuthResult({this.error, this.info, this.notice});
  bool get ok => error == null && info == null;
}

/// Orkestrasi akun: Supabase Auth sebagai sumber kebenaran, akun lokal sebagai
/// cermin (offline, profil, avatar). ID akun lokal == auth.uid() Supabase,
/// sehingga data lokal dan baris cloud (RLS) memiliki pemilik yang sama.
///
/// Migrasi akun lokal lama (ID acak) terjadi otomatis saat login pertama:
/// dibuat akun cloud dengan email+password yang sama, lalu seluruh data lokal
/// dipindah ke ID baru dan dikirim ke cloud. Tidak ada data yang dihapus.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final _storage = StorageService.instance;
  final _supa = SupabaseService.instance;

  bool get _cloudAvailable => _supa.isInitialized && _supa.client != null;

  static String _norm(String email) => email.trim();

  // ---------- util ----------
  static bool _isInvalidCredentials(AuthException e) {
    final m = e.message.toLowerCase();
    return m.contains('invalid login credentials') || m.contains('invalid_credentials');
  }

  static bool _isNotConfirmed(AuthException e) =>
      e.message.toLowerCase().contains('not confirmed');

  static bool _isAlreadyRegistered(AuthException e) {
    final m = e.message.toLowerCase();
    return m.contains('already registered') ||
        m.contains('already been registered') ||
        m.contains('user_already_exists');
  }

  /// Gagal jaringan (bukan penolakan server).
  static bool _isNetwork(Object e) {
    if (e is AuthRetryableFetchException) return true;
    if (e is AuthException) return false;
    return true; // SocketException, ClientException, Timeout, dll.
  }

  Future<void> _markLinked(String uid) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('cloud_linked_$uid', true);
  }

  /// Apakah akun lokal ini sudah terhubung ke akun Supabase.
  Future<bool> isCloudLinked(String userId) async {
    final p = await SharedPreferences.getInstance();
    return p.getBool('cloud_linked_$userId') ?? false;
  }

  // ---------- daftar ----------
  Future<AuthResult> register({
    required String username,
    required String email,
    required String password,
  }) async {
    email = _norm(email);
    if (password.length < 6) {
      return const AuthResult(error: 'Password minimal 6 karakter');
    }
    if (await _storage.findUserByEmail(email) != null) {
      return const AuthResult(error: 'Email sudah terdaftar. Silakan masuk.');
    }

    if (!_cloudAvailable) {
      // Supabase tidak terkonfigurasi: mode lokal murni.
      final u = await _storage.createLocalUser(
        username: username, email: email, password: password);
      await _storage.setCurrentUserId(u.id);
      return const AuthResult();
    }

    try {
      final res = await _supa.client!.auth.signUp(
        email: email,
        password: password,
        data: {'username': username},
      );
      final user = res.user;
      if (user == null) {
        return const AuthResult(error: 'Gagal membuat akun. Coba lagi.');
      }
      // Email sudah dipakai: Supabase (dengan konfirmasi email aktif) mengembalikan
      // user tanpa identities dan tanpa error, demi privasi.
      if (user.identities != null && user.identities!.isEmpty) {
        return const AuthResult(
          error: 'Email sudah terdaftar. Silakan masuk atau atur ulang password.',
        );
      }
      if (res.session == null) {
        return const AuthResult(
          info: 'Akun dibuat. Kami mengirim email konfirmasi — buka tautannya, '
              'lalu kembali dan masuk.',
        );
      }
      final local = await _storage.createLocalUser(
        id: user.id, username: username, email: email, password: password);
      await _markLinked(local.id);
      await _storage.setCurrentUserId(local.id);
      SyncService.instance.start();
      return const AuthResult();
    } on AuthException catch (e) {
      if (_isAlreadyRegistered(e)) {
        return const AuthResult(
          error: 'Email sudah terdaftar. Silakan masuk atau atur ulang password.',
        );
      }
      if (_isNetwork(e)) {
        return const AuthResult(error: 'Tidak ada koneksi internet. Pendaftaran butuh internet.');
      }
      return AuthResult(error: e.message);
    } catch (_) {
      return const AuthResult(error: 'Tidak ada koneksi internet. Pendaftaran butuh internet.');
    }
  }

  // ---------- masuk ----------
  Future<AuthResult> login({required String email, required String password}) async {
    email = _norm(email);
    final local = await _storage.findUserByEmail(email);
    final localOk = local != null && await _storage.verifyLocalPassword(local, password);

    if (!_cloudAvailable) {
      if (!localOk) return const AuthResult(error: 'Email atau password salah');
      await _storage.setCurrentUserId(local.id);
      return const AuthResult();
    }

    try {
      final res = await _supa.client!.auth.signInWithPassword(email: email, password: password);
      final cloudUser = res.user;
      if (cloudUser == null) return const AuthResult(error: 'Email atau password salah');
      await _adoptCloudUser(cloudUser, local, password);
      return const AuthResult();
    } on AuthException catch (e) {
      if (_isNotConfirmed(e)) {
        return const AuthResult(error: 'Email belum dikonfirmasi. Cek kotak masuk Anda.');
      }
      if (_isInvalidCredentials(e)) {
        if (!localOk) return const AuthResult(error: 'Email atau password salah');
        return _linkLegacyAccount(local, password);
      }
      if (_isNetwork(e)) return _offlineLogin(local, localOk);
      return AuthResult(error: e.message);
    } catch (_) {
      return _offlineLogin(local, localOk);
    }
  }

  // ---------- masuk dengan Google ----------
  Future<AuthResult> signInWithGoogle() async {
    try {
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        return const AuthResult(
          error: 'Google Sign-In tidak didukung pada perangkat ini.',
        );
      }

      final googleUser = await GoogleSignIn.instance.authenticate(
        scopeHint: [GoogleDriveService.driveScope],
      );

      final email = _norm(googleUser.email);
      final displayName = googleUser.displayName?.trim();
      final username = (displayName != null && displayName.isNotEmpty)
          ? displayName
          : (email.contains('@') ? email.split('@').first : 'Pengguna');

      var local = await _storage.findUserByEmail(email);

      String? cloudUid;
      if (_cloudAvailable) {
        try {
          final googleAuth = googleUser.authentication;
          final idToken = googleAuth.idToken;
          if (idToken != null) {
            final res = await _supa.client!.auth.signInWithIdToken(
              provider: OAuthProvider.google,
              idToken: idToken,
            );
            if (res.user != null) {
              cloudUid = res.user!.id;
            }
          }
        } catch (e) {
          debugPrint('Supabase Google Sign-In: $e');
        }
      }

      if (local == null) {
        local = await _storage.createLocalUser(
          id: cloudUid,
          username: username,
          email: email,
          password: '',
          seedCategories: true,
        );
      } else if (cloudUid != null && local.id != cloudUid) {
        await _storage.rekeyUser(local.id, cloudUid);
        local = local.copyWithId(cloudUid);
      }

      await _storage.setCurrentUserId(local.id);

      if (cloudUid != null) {
        await _markLinked(cloudUid);
        SyncService.instance.start();
        unawaited(SyncService.instance.syncNow());
      }

      // Hubungkan akun Google ke GoogleDriveService untuk backup
      await GoogleDriveService.instance.setAccount(googleUser);

      return const AuthResult();
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('canceled') || msg.contains('cancelled') || msg.contains('aborted')) {
        return const AuthResult();
      }
      return AuthResult(error: 'Gagal masuk dengan Google: $e');
    }
  }

  /// Login cloud berhasil: hubungkan/migrasikan akun lokal lalu sinkronkan.
  Future<void> _adoptCloudUser(User cloudUser, UserModel? local, String password) async {
    final uid = cloudUser.id;
    final email = cloudUser.email ?? local?.email ?? '';
    if (local == null) {
      final name = (cloudUser.userMetadata?['username'] as String?) ??
          (email.contains('@') ? email.split('@').first : 'Pengguna');
      await _storage.createLocalUser(
        id: uid, username: name, email: email, password: password, seedCategories: false);
    } else {
      if (local.id != uid) await _storage.rekeyUser(local.id, uid); // MIGRASI
      await _storage.setLocalPassword(uid, password);
    }
    await _markLinked(uid);
    await _storage.setCurrentUserId(uid);
    SyncService.instance.start();
    // Tunggu sinkron pertama sebentar agar data cloud sudah ada saat layar dibuka.
    await SyncService.instance
        .syncNow()
        .timeout(const Duration(seconds: 20), onTimeout: () => false);
  }

  /// Akun lokal lama yang belum ada di cloud: buat akun cloud dari kredensial
  /// yang sama, lalu pindahkan datanya.
  Future<AuthResult> _linkLegacyAccount(UserModel local, String password) async {
    try {
      final res = await _supa.client!.auth.signUp(
        email: local.email,
        password: password,
        data: {'username': local.username},
      );
      final user = res.user;
      final alreadyExists = user != null && (user.identities?.isEmpty ?? false);
      if (user != null && !alreadyExists && res.session != null) {
        await _adoptCloudUser(user, local, password);
        return const AuthResult(
          notice: 'Akunmu kini terhubung ke cloud. Data lama sedang disinkronkan.',
        );
      }
      await _storage.setCurrentUserId(local.id);
      if (user != null && !alreadyExists) {
        return const AuthResult(
          notice: 'Kami mengirim email konfirmasi. Setelah dikonfirmasi, masuk lagi '
              'untuk menyinkronkan data ke cloud.',
        );
      }
      return const AuthResult(
        notice: 'Email ini sudah punya akun cloud dengan password berbeda. Datamu aman '
            'di perangkat ini. Masuk dengan password cloud (atau atur ulang password) '
            'untuk menyinkronkan.',
      );
    } on AuthException catch (e) {
      await _storage.setCurrentUserId(local.id);
      if (_isAlreadyRegistered(e)) {
        return const AuthResult(
          notice: 'Email ini sudah punya akun cloud dengan password berbeda. Datamu aman '
              'di perangkat ini. Masuk dengan password cloud (atau atur ulang password) '
              'untuk menyinkronkan.',
        );
      }
      return const AuthResult(notice: 'Masuk dalam mode lokal. Sinkronisasi cloud belum aktif.');
    } catch (_) {
      await _storage.setCurrentUserId(local.id);
      return const AuthResult(notice: 'Tidak ada koneksi. Masuk dalam mode offline.');
    }
  }

  Future<AuthResult> _offlineLogin(UserModel? local, bool localOk) async {
    if (local != null && localOk) {
      await _storage.setCurrentUserId(local.id);
      return const AuthResult(notice: 'Tidak ada koneksi. Masuk dalam mode offline.');
    }
    return const AuthResult(
      error: 'Tidak ada koneksi internet. Login pertama di perangkat ini butuh internet.',
    );
  }

  // ---------- ganti password ----------
  /// Mengubah password lokal dan, bila akun terhubung, password Supabase.
  Future<String?> changePassword({
    required String userId,
    required String oldPassword,
    required String newPassword,
  }) async {
    final user = await _storage.getCurrentUser();
    if (user == null || user.id != userId) return 'User tidak ditemukan';
    if (!await _storage.verifyLocalPassword(user, oldPassword)) return 'Password lama salah';

    if (await isCloudLinked(userId)) {
      final signedInAsUser = _supa.currentUser?.id == userId;
      if (!signedInAsUser) {
        return 'Sesi cloud berakhir. Keluar lalu masuk lagi sebelum mengubah password.';
      }
      try {
        await _supa.client!.auth.updateUser(UserAttributes(password: newPassword));
      } on AuthException catch (e) {
        return _isNetwork(e)
            ? 'Tidak ada koneksi internet. Perubahan password butuh internet.'
            : e.message;
      } catch (_) {
        return 'Tidak ada koneksi internet. Perubahan password butuh internet.';
      }
    }
    await _storage.setLocalPassword(userId, newPassword);
    return null;
  }

  /// Setelah login: minta izin notifikasi sekali, lalu daftarkan token FCM.
  Future<void> afterLogin() async {
    unawaited(FcmService.instance.onLogin());
  }
}
