class CategoryModel {
  const CategoryModel({
    required this.categoryId,
    required this.categoryName,
    this.categoryDescription,
    required this.subcategoryCount,
    this.totalLandCount,
    this.subcategories = const [],
  });

  final int categoryId;
  final String categoryName;
  final String? categoryDescription;
  final int subcategoryCount;
  final int? totalLandCount;
  final List<SubcategoryModel> subcategories;

  int get id => categoryId;
  String get name => categoryName;

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    final data = _normalizeJsonKeys(json);
    return CategoryModel(
      categoryId: _asInt(data['categoryId']),
      categoryName: data['categoryName']?.toString() ?? '',
      categoryDescription: _asNullableString(data['categoryDescription']),
      subcategoryCount: _asInt(
        data['subcategoryCount'],
        fallback: (data['subcategories'] as List<dynamic>? ?? const []).length,
      ),
      totalLandCount: _asNullableInt(data['totalLandCount']),
      subcategories: (data['subcategories'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((json) =>
              SubcategoryModel.fromJson(Map<String, dynamic>.from(json)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'categoryId': categoryId,
        'categoryName': categoryName,
        'categoryDescription': categoryDescription,
        'subcategoryCount': subcategoryCount,
        'totalLandCount': totalLandCount,
        'subcategories': subcategories.map((sub) => sub.toJson()).toList(),
      };

  SubcategoryModel? findSubcategory(String name) {
    try {
      return subcategories.firstWhere(
        (subcategory) => subcategory.subcategoryName == name,
      );
    } catch (_) {
      return null;
    }
  }
}

class SubcategoryModel {
  const SubcategoryModel({
    required this.subcategoryId,
    required this.subcategoryName,
    this.subcategoryDescription,
    this.landCount,
    required this.farmerCount,
  });

  final int subcategoryId;
  final String subcategoryName;
  final String? subcategoryDescription;
  final int? landCount;
  final int farmerCount;

  int get id => subcategoryId;
  String get name => subcategoryName;

  factory SubcategoryModel.fromJson(Map<String, dynamic> json) {
    final data = _normalizeJsonKeys(json);
    return SubcategoryModel(
      subcategoryId: _asInt(data['subcategoryId']),
      subcategoryName: data['subcategoryName']?.toString() ?? '',
      subcategoryDescription: _asNullableString(data['subcategoryDescription']),
      landCount: _asNullableInt(data['landCount']),
      farmerCount: _asInt(data['farmerCount']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'subcategoryId': subcategoryId,
        'subcategoryName': subcategoryName,
        'subcategoryDescription': subcategoryDescription,
        'landCount': landCount,
        'farmerCount': farmerCount,
      };
}

Map<String, dynamic> _normalizeJsonKeys(Map<String, dynamic> json) {
  final normalized = <String, dynamic>{};
  json.forEach((key, value) {
    normalized[_toCamelCase(key)] = value;
  });
  return normalized;
}

String _toCamelCase(String input) {
  if (!input.contains('_')) return input;
  final segments = input.split('_');
  if (segments.isEmpty) return input;
  return segments.first +
      segments
          .skip(1)
          .where((segment) => segment.isNotEmpty)
          .map(
            (segment) => '${segment[0].toUpperCase()}${segment.substring(1)}',
          )
          .join();
}

String? _asNullableString(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) {
    return null;
  }
  return text;
}

int _asInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

int? _asNullableInt(Object? value) {
  if (value == null) return null;
  return _asInt(value);
}
