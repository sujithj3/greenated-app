import 'package:flutter/material.dart';

/// Data for a single category (icon, color, subcategory list).
class CategoryData {
  final IconData icon;
  final Color color;
  final List<String> subcategories;

  const CategoryData({
    required this.icon,
    required this.color,
    required this.subcategories,
  });
}

/// All categories and their metadata.
class AppCategories {
  static const Map<String, CategoryData> all = {
    'Agroforestry': CategoryData(
      icon: Icons.park,
      color: Color(0xFF2E7D32),
      subcategories: [],
    ),
    'Soil Carbon': CategoryData(
      icon: Icons.terrain,
      color: Color(0xFF5D4037),
      subcategories: [],
    ),
    'Biochar': CategoryData(
      icon: Icons.whatshot,
      color: Color(0xFF37474F),
      subcategories: [],
    ),
  };

  static CategoryData? styleFor(String category) => all[category];

  static List<String> getSubcategories(String category) {
    return all[category]?.subcategories ?? [];
  }
}
