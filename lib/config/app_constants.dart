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
      subcategories: [
        'Silvopasture',
        'Alley Cropping',
        'Forest Farming',
        'Riparian Buffers',
        'Windbreaks & Shelterbelts',
        'Multi-strata Systems',
        'Homegardens',
        'Taungya System',
      ],
    ),
    'Soil Carbon': CategoryData(
      icon: Icons.terrain,
      color: Color(0xFF5D4037),
      subcategories: [
        'Cover Cropping',
        'No-till / Reduced Tillage',
        'Rotational Grazing',
        'Compost Application',
        'Biosolids Application',
        'Wetland Restoration',
        'Grassland Management',
      ],
    ),
    'Biochar': CategoryData(
      icon: Icons.whatshot,
      color: Color(0xFF37474F),
      subcategories: [
        'Wood Biochar',
        'Crop Residue Biochar',
        'Bamboo Biochar',
        'Municipal Waste Biochar',
        'Co-composting with Biochar',
        'Livestock Manure Biochar',
      ],
    ),
  };

  static List<String> getSubcategories(String category) {
    return all[category]?.subcategories ?? [];
  }
}
