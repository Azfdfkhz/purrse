class BackupModel {
  final String app;
  final int backupVersion;
  final String appVersion;
  final String createdAt;

  final Map<String, dynamic> user;
  final List<Map<String, dynamic>> transactions;
  final List<Map<String, dynamic>> categories;
  final Map<String, dynamic> settings;

  const BackupModel({
    required this.app,
    required this.backupVersion,
    required this.appVersion,
    required this.createdAt,
    required this.user,
    required this.transactions,
    required this.categories,
    required this.settings,
  });

  Map<String, dynamic> toJson() {
    return {
      'app': app,
      'backupVersion': backupVersion,
      'appVersion': appVersion,
      'createdAt': createdAt,
      'data': {
        'user': user,
        'transactions': transactions,
        'categories': categories,
        'settings': settings,
      },
    };
  }

  factory BackupModel.fromJson(
      Map<String, dynamic> json,
      ) {
    final data = Map<String, dynamic>.from(
      json['data'] ?? {},
    );

    return BackupModel(
      app: json['app']?.toString() ?? '',
      backupVersion:
      (json['backupVersion'] as num?)?.toInt() ?? 1,
      appVersion:
      json['appVersion']?.toString() ?? 'unknown',
      createdAt:
      json['createdAt']?.toString() ?? '',
      user: Map<String, dynamic>.from(
        data['user'] ?? {},
      ),
      transactions: List<Map<String, dynamic>>.from(
        (data['transactions'] as List? ?? []).map(
              (e) => Map<String, dynamic>.from(e),
        ),
      ),
      categories: List<Map<String, dynamic>>.from(
        (data['categories'] as List? ?? []).map(
              (e) => Map<String, dynamic>.from(e),
        ),
      ),
      settings: Map<String, dynamic>.from(
        data['settings'] ?? {},
      ),
    );
  }
}