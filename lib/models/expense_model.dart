class ExpenseModel {
  final String id;
  final String userId;
  final String categoryId;
  final double amount;
  final DateTime date;
  final String description;
  final String? proofPath;

  ExpenseModel({
    required this.id,
    required this.userId,
    required this.categoryId,
    required this.amount,
    required this.date,
    required this.description,
    this.proofPath,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'categoryId': categoryId,
        'amount': amount,
        'date': date.toIso8601String(),
        'description': description,
        'proofPath': proofPath,
      };

  factory ExpenseModel.fromJson(Map<String, dynamic> json) => ExpenseModel(
        id: json['id'],
        userId: json['userId'],
        categoryId: json['categoryId'],
        amount: (json['amount'] as num).toDouble(),
        date: DateTime.parse(json['date']),
        description: json['description'] ?? '',
        proofPath: json['proofPath'],
      );
}
