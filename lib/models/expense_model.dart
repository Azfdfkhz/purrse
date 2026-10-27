/// Status upload foto bukti ke Google Drive.
class UploadStatus {
  UploadStatus._();
  static const none = 'none'; // tidak ada foto
  static const pending = 'pending'; // menunggu
  static const uploading = 'uploading'; // sedang diunggah
  static const uploaded = 'uploaded'; // berhasil (dikonfirmasi Drive)
  static const failed = 'failed'; // gagal, akan dicoba ulang
  static const needsAuth = 'needsAuth'; // Drive belum terhubung / izin habis
}

/// Status sinkronisasi ke cloud (disiapkan untuk Supabase).
class SyncState {
  SyncState._();
  static const pending = 'pending'; // ada perubahan lokal yang belum terkirim
  static const synced = 'synced'; // sudah dikonfirmasi server
}

class ExpenseModel {
  final String id;
  final String userId;
  final String categoryId;
  final double amount;

  /// Tanggal KEJADIAN transaksi (tanpa jam, zona waktu lokal).
  /// Berbeda dengan [createdAt] / [updatedAt].
  final DateTime date;
  final String description;
  final String? proofPath;

  /// Waktu data dibuat / terakhir diubah (UTC). Bukan tanggal transaksi.
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Tombstone untuk penghapusan (agar bisa disinkronkan).
  final DateTime? deletedAt;

  final String syncState;

  // Foto bukti -> Google Drive
  final String? driveFileId;
  final String uploadStatus;
  final int uploadAttempts;
  final DateTime? nextRetryAt;
  final String? uploadError;

  ExpenseModel({
    required this.id,
    required this.userId,
    required this.categoryId,
    required this.amount,
    required DateTime date,
    required this.description,
    this.proofPath,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deletedAt,
    this.syncState = SyncState.pending,
    this.driveFileId,
    String? uploadStatus,
    this.uploadAttempts = 0,
    this.nextRetryAt,
    this.uploadError,
  })  : date = dateOnly(date),
        createdAt = createdAt ?? DateTime.now().toUtc(),
        updatedAt = updatedAt ?? DateTime.now().toUtc(),
        uploadStatus = uploadStatus ??
            ((proofPath != null && proofPath.isNotEmpty)
                ? UploadStatus.pending
                : UploadStatus.none);

  bool get isDeleted => deletedAt != null;
  bool get hasProof => proofPath != null && proofPath!.isNotEmpty;

  /// Buang jam/zona waktu: hanya y-m-d lokal.
  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Mendukung format baru ("2026-10-27") dan format lama (ISO 8601 penuh).
  static DateTime parseDate(String raw) {
    final simple = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw);
    if (simple != null) {
      return DateTime(
        int.parse(simple.group(1)!),
        int.parse(simple.group(2)!),
        int.parse(simple.group(3)!),
      );
    }
    final parsed = DateTime.parse(raw);
    final local = parsed.isUtc ? parsed.toLocal() : parsed;
    return DateTime(local.year, local.month, local.day);
  }

  ExpenseModel copyWith({
    String? userId,
    String? categoryId,
    double? amount,
    DateTime? date,
    String? description,
    String? proofPath,
    bool clearProof = false,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    String? syncState,
    String? driveFileId,
    bool clearDriveFileId = false,
    String? uploadStatus,
    int? uploadAttempts,
    DateTime? nextRetryAt,
    bool clearNextRetry = false,
    String? uploadError,
    bool clearUploadError = false,
  }) {
    final newProof = clearProof ? null : (proofPath ?? this.proofPath);
    return ExpenseModel(
      id: id,
      userId: userId ?? this.userId,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      description: description ?? this.description,
      proofPath: newProof,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      syncState: syncState ?? this.syncState,
      driveFileId: clearDriveFileId ? null : (driveFileId ?? this.driveFileId),
      uploadStatus: uploadStatus ??
          (newProof == null ? UploadStatus.none : this.uploadStatus),
      uploadAttempts: uploadAttempts ?? this.uploadAttempts,
      nextRetryAt: clearNextRetry ? null : (nextRetryAt ?? this.nextRetryAt),
      uploadError: clearUploadError ? null : (uploadError ?? this.uploadError),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'categoryId': categoryId,
        'amount': amount,
        'date': dateKey(date),
        'description': description,
        'proofPath': proofPath,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'deletedAt': deletedAt?.toIso8601String(),
        'syncState': syncState,
        'driveFileId': driveFileId,
        'uploadStatus': uploadStatus,
        'uploadAttempts': uploadAttempts,
        'nextRetryAt': nextRetryAt?.toIso8601String(),
        'uploadError': uploadError,
      };

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    DateTime? ts(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString())?.toUtc();
    final proof = json['proofPath'] as String?;
    return ExpenseModel(
      id: json['id'],
      userId: json['userId'],
      categoryId: json['categoryId'],
      amount: (json['amount'] as num).toDouble(),
      date: parseDate(json['date'].toString()),
      description: json['description'] ?? '',
      proofPath: proof,
      createdAt: ts(json['createdAt']),
      updatedAt: ts(json['updatedAt']) ?? ts(json['createdAt']),
      deletedAt: ts(json['deletedAt']),
      syncState: json['syncState'] ?? SyncState.pending,
      driveFileId: json['driveFileId'] as String?,
      uploadStatus: json['uploadStatus'] as String?,
      uploadAttempts: (json['uploadAttempts'] as num?)?.toInt() ?? 0,
      nextRetryAt: ts(json['nextRetryAt']),
      uploadError: json['uploadError'] as String?,
    );
  }
}
