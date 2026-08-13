import 'package:flutter/material.dart';

class CategoryModel {
  final String id;
  final String name;
  final Color color;
  final IconData icon;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'color': color.value,
    'codePoint': icon.codePoint,
    'fontFamily': icon.fontFamily,
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

    return CategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      color: Color(json['color'] as int),
      icon: iconData,
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