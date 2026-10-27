import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// PBKDF2-HMAC-SHA256 (RFC 8018), satu blok 32 byte.
/// Catatan: ini penguatan untuk penyimpanan lokal. Untuk akun lintas
/// perangkat, gunakan penyedia autentikasi server (mis. Supabase Auth).
class PasswordHasher {
  PasswordHasher._();

  static const int iterations = 60000;

  static String generateSalt([int length = 16]) {
    final rnd = Random.secure();
    return base64Encode(List<int>.generate(length, (_) => rnd.nextInt(256)));
  }

  static String hash(String password, String saltB64) {
    final hmac = Hmac(sha256, utf8.encode(password));
    final salt = base64Decode(saltB64);
    var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final t = List<int>.from(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < t.length; j++) {
        t[j] ^= u[j];
      }
    }
    return base64Encode(t);
  }

  static bool verify(String password, String saltB64, String expectedHash) {
    final actual = hash(password, saltB64);
    if (actual.length != expectedHash.length) return false;
    var diff = 0;
    for (var i = 0; i < actual.length; i++) {
      diff |= actual.codeUnitAt(i) ^ expectedHash.codeUnitAt(i);
    }
    return diff == 0;
  }
}
