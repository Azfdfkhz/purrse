import 'package:flutter/material.dart';

class CategoryModel {
  final String id;
  final String name;
  final Color color;
  final IconData icon;

  /// Untuk sinkronisasi: waktu terakhir diubah (UTC) dan tombstone hapus.
  /// Null pada data lama; diperlakukan sebagai "sangat lama".
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
    this.updatedAt,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  CategoryModel copyWith({
    String? name,
    Color? color,
    IconData? icon,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) =>
      CategoryModel(
        id: id,
        name: name ?? this.name,
        color: color ?? this.color,
        icon: icon ?? this.icon,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'color': color.toARGB32(),
    'codePoint': icon.codePoint,
    'fontFamily': icon.fontFamily,
    'updatedAt': updatedAt?.toIso8601String(),
    'deletedAt': deletedAt?.toIso8601String(),
  };

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    // Akomodasi kompatibilitas data lama (String name) atau data baru (codePoint)
    IconData iconData;
    if (json.containsKey('codePoint')) {
      iconData = IconData(
        json['codePoint'] as int,
        fontFamily: json['fontFamily'] as String? ?? 'MaterialIcons',
      );
    } else {
      iconData = _iconFromName(json['icon'] as String?);
    }

    DateTime? ts(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString())?.toUtc();

    return CategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      color: Color(json['color'] as int),
      icon: iconData,
      updatedAt: ts(json['updatedAt']),
      deletedAt: ts(json['deletedAt']),
    );
  }

  static IconData _iconFromName(String? name) {
    switch (name) {
      case 'restaurant': return Icons.restaurant;
      case 'directions_car': return Icons.directions_car;
      case 'shopping_bag': return Icons.shopping_bag;
      case 'receipt_long': return Icons.receipt_long;
      case 'school': return Icons.school;
      case 'medical_services': return Icons.medical_services;
      case 'home': return Icons.home;
      case 'phone_android': return Icons.phone_android;
      case 'sports_esports': return Icons.sports_esports;
      case 'flight': return Icons.flight;
      case 'account_balance_wallet': return Icons.account_balance_wallet;
      case 'movie_filters' : return Icons.movie;
      default: return Icons.category;
    }
  }
}
