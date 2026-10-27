class UserModel {
  final String id;
  final String username;
  final String email;

  /// Hash PBKDF2-HMAC-SHA256 (base64) + salt (base64).
  final String? passwordHash;
  final String? passwordSalt;

  /// HANYA untuk data lama (versi <= 1.1.0) yang masih teks biasa.
  /// Dihapus otomatis saat user berhasil login pertama kali di 1.2.0.
  final String? legacyPassword;
  final String? avatarPath;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    this.passwordHash,
    this.passwordSalt,
    this.legacyPassword,
    this.avatarPath,
  });

  UserModel copyWith({
    String? username,
    String? avatarPath,
    String? passwordHash,
    String? passwordSalt,
    bool clearLegacyPassword = false,
  }) =>
      UserModel(
        id: id,
        username: username ?? this.username,
        email: email,
        passwordHash: passwordHash ?? this.passwordHash,
        passwordSalt: passwordSalt ?? this.passwordSalt,
        legacyPassword: clearLegacyPassword ? null : legacyPassword,
        avatarPath: avatarPath ?? this.avatarPath,
      );

  UserModel copyWithId(String newId) => UserModel(
        id: newId,
        username: username,
        email: email,
        passwordHash: passwordHash,
        passwordSalt: passwordSalt,
        legacyPassword: legacyPassword,
        avatarPath: avatarPath,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'email': email,
        'passwordHash': passwordHash,
        'passwordSalt': passwordSalt,
        if (legacyPassword != null) 'password': legacyPassword,
        'avatarPath': avatarPath,
      };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'],
        username: json['username'],
        email: json['email'],
        passwordHash: json['passwordHash'],
        passwordSalt: json['passwordSalt'],
        legacyPassword: json['password'],
        avatarPath: json['avatarPath'],
      );
}
