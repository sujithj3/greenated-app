/// A top-level project category (e.g. Agroforestry, Soil Carbon, Biochar) and
/// the subcategories nested beneath it.
///
/// This is the backbone of the app's category-browsing layer: the backend
/// returns categories as JSON, [fromJson] parses them into typed objects the
/// UI lists, and [toJson] serializes them back. Each category aggregates
/// counts ([subcategoryCount], [totalLandCount]) and owns a list of
/// [SubcategoryModel]s. Parsing is deliberately lenient (mixed key casing,
/// numbers sent as strings) via the JSON helpers at the bottom of the file.
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

  /// Generic id accessor (aliases [categoryId]) so category and subcategory
  /// models expose a uniform id/name interface.
  int get id => categoryId;

  /// Generic name accessor (aliases [categoryName]).
  String get name => categoryName;

  /// Builds a [CategoryModel] from backend JSON.
  ///
  /// When the payload omits `subcategoryCount`, it falls back to the length of
  /// the parsed `subcategories` list so the count is always populated.
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

  /// Returns the subcategory whose [SubcategoryModel.subcategoryName] equals
  /// [name], or null when no match exists.
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

/// A subcategory nested under a [CategoryModel] (e.g. a specific programme or
/// crop type).
///
/// Carries its own [farmerCount] / [landCount] tallies and an optional display
/// [headerTitle]. Parsed from backend JSON via [fromJson] and serialized back
/// via [toJson].
class SubcategoryModel {
  const SubcategoryModel({
    required this.subcategoryId,
    required this.subcategoryName,
    this.subcategoryDescription,
    this.landCount,
    required this.farmerCount,
    this.headerTitle,
  });

  final int subcategoryId;
  final String subcategoryName;
  final String? subcategoryDescription;
  final int? landCount;
  final int farmerCount;
  final String? headerTitle;
  /// Generic id accessor (aliases [subcategoryId]).
  int get id => subcategoryId;

  /// Generic name accessor (aliases [subcategoryName]).
  String get name => subcategoryName;

  factory SubcategoryModel.fromJson(Map<String, dynamic> json) {
    final data = _normalizeJsonKeys(json);
    return SubcategoryModel(
      subcategoryId: _asInt(data['subcategoryId']),
      subcategoryName: data['subcategoryName']?.toString() ?? '',
      subcategoryDescription: _asNullableString(data['subcategoryDescription']),
      landCount: _asNullableInt(data['landCount']),
      farmerCount: _asInt(data['farmerCount']),
      headerTitle: _asNullableString(data['headerTitle']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'subcategoryId': subcategoryId,
        'subcategoryName': subcategoryName,
        'subcategoryDescription': subcategoryDescription,
        'landCount': landCount,
        'farmerCount': farmerCount,
        'headerTitle': headerTitle,
      };
}

// ─────────────────────────────────────────────────────────────────────────
// JSON helpers
//
// Shared, defensive utilities used by the models above to tolerate the
// backend's inconsistencies: mixed key casing and numbers sent as strings.
// Keeping the parsing lenient here means the model constructors stay simple
// and never throw on odd payloads.
// ─────────────────────────────────────────────────────────────────────────

/// Returns a copy of [json] with every key converted to camelCase so the
/// models can read a single canonical key regardless of the source casing.
Map<String, dynamic> _normalizeJsonKeys(Map<String, dynamic> json) {
  final normalized = <String, dynamic>{};
  json.forEach((key, value) {
    normalized[_toCamelCase(key)] = value;
  });
  return normalized;
}

/// Converts a `snake_case` identifier to `camelCase`; returns [input] as-is
/// when it contains no underscores.
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

/// Trims [value] to a string, collapsing null/empty results to null.
String? _asNullableString(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) {
    return null;
  }
  return text;
}

/// Safely coerces [value] (int, num or numeric string) to an int, returning
/// [fallback] when it cannot be parsed.
int _asInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

/// Like [_asInt] but preserves null: returns null for a null [value] rather
/// than the zero fallback, used for optional count fields.
int? _asNullableInt(Object? value) {
  if (value == null) return null;
  return _asInt(value);
}
