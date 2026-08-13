class UserModel {
  final String id;
  final String username;
  final String email;
  final String password; // demo only - simple local storage, not secure
  final String? avatarPath;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.password,
    this.avatarPath,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'email': email,
        'password': password,
        'avatarPath': avatarPath,
      };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'],
        username: json['username'],
        email: json['email'],
        password: json['password'],
        avatarPath: json['avatarPath'],
      );
}
