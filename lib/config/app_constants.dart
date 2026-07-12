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

/// App-wide catalogue of the fixed project categories and their presentation
/// metadata.
///
/// This is the single source of truth for the categories the app ships with —
/// Agroforestry, Soil Carbon and Biochar — pairing each name with a
/// [CategoryData] (icon and colour) so category tiles are styled consistently
/// across screens. Unlike the server-driven `CategoryModel`, these entries are
/// compile-time constants used purely for local UI presentation.
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

  /// Returns the [CategoryData] styling for [category], or null when it is not
  /// a known category.
  static CategoryData? styleFor(String category) => all[category];

  /// Returns the configured subcategory names for [category], or an empty list
  /// when the category is unknown or has none.
  static List<String> getSubcategories(String category) {
    return all[category]?.subcategories ?? [];
  }
}
