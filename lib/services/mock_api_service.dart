import '../models/api/api_models.dart';

/// ──────────────────────────────────────────────────────────────────────────────
/// MockApiService — Temporary mock API layer for subcategories & dynamic fields.
///
/// ⚠️  This file is a placeholder until the real backend API is ready.
///     Replace the mock JSON data with actual HTTP calls when available.
///
/// Method signatures mirror the real API service so the swap is minimal:
///   • getCategories()
///   • getSubCategories(categoryId)
///   • getDynamicRegistrationFields(subCategoryId)
/// ──────────────────────────────────────────────────────────────────────────────

class MockApiService {
  MockApiService._();

  // ── Simulated network latency ─────────────────────────────────────────────
  static const _mockDelay = Duration(milliseconds: 600);

  // ─────────────────────────────────────────────────────────────────────────────
  // 1. GET CATEGORIES (with embedded subcategories)
  // ─────────────────────────────────────────────────────────────────────────────
  /// Returns the full category list with subcategories, matching the expected
  /// backend API response structure.
  ///
  /// **Expected real API endpoint:** `GET /api/v1/categories`
  ///
  /// **Expected JSON response:**
  /// ```json
  /// {
  ///   "statusCode": 200,
  ///   "status": "success",
  ///   "message": "Categories fetched successfully",
  ///   "data": [ ...ApiCategory objects... ]
  /// }
  /// ```
  static Future<List<ApiCategory>> getCategories() async {
    await Future.delayed(_mockDelay);

    // ── Mock JSON that mirrors the real backend response ──────────────────
    // Each category contains its subcategories; each subcategory contains
    // its form configuration with sections and fields.
    //
    // The JSON below is parsed through the existing fromJson() factories,
    // so it also serves as a contract reference for the backend team.
    final mockResponseJson = <String, dynamic>{
      'statusCode': 200,
      'status': 'success',
      'message': 'Categories fetched successfully',
      'data': [
        _agroforestryCategoryJson(),
        _soilCarbonCategoryJson(),
        _biocharCategoryJson(),
      ],
    };

    // Parse through the same path the real API response would use
    final data = mockResponseJson['data'] as List<dynamic>;
    return data
        .map((c) => ApiCategory.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 2. GET SUBCATEGORIES (by category ID)
  // ─────────────────────────────────────────────────────────────────────────────
  /// Returns subcategories for a specific category.
  ///
  /// **Expected real API endpoint:** `GET /api/v1/categories/{categoryId}/subcategories`
  ///
  /// **Expected JSON response:**
  /// ```json
  /// {
  ///   "statusCode": 200,
  ///   "status": "success",
  ///   "message": "Subcategories fetched successfully",
  ///   "data": {
  ///     "category_id": 1,
  ///     "category_name": "Agroforestry",
  ///     "subcategories": [
  ///       {
  ///         "subcategory_id": 100,
  ///         "subcategory_name": "Silvopasture",
  ///         "forms": [ ... ]
  ///       }
  ///     ]
  ///   }
  /// }
  /// ```
  static Future<List<ApiSubcategory>> getSubCategories(int categoryId) async {
    await Future.delayed(_mockDelay);

    // Get full categories and find the matching one
    final categories = await getCategories();
    final category = categories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => const ApiCategory(id: -1, name: '', subcategories: []),
    );

    return category.subcategories;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 3. GET DYNAMIC REGISTRATION FIELDS (by subcategory ID)
  // ─────────────────────────────────────────────────────────────────────────────
  /// Returns the dynamic form configuration for a specific subcategory.
  /// This powers the farmer registration form.
  ///
  /// **Expected real API endpoint:**
  ///   `GET /api/v1/subcategories/{subCategoryId}/registration-fields`
  ///
  /// **Expected JSON response:**
  /// ```json
  /// {
  ///   "statusCode": 200,
  ///   "status": "success",
  ///   "message": "Registration fields fetched successfully",
  ///   "data": {
  ///     "subcategory_id": 100,
  ///     "subcategory_name": "Silvopasture",
  ///     "forms": [
  ///       {
  ///         "form_id": 1000,
  ///         "form_name": "Greenated",
  ///         "form_config": { "geoLocationRequired": true },
  ///         "sections": [
  ///           {
  ///             "section_id": "personal_info",
  ///             "section_title": "Personal Info",
  ///             "fields": [
  ///               {
  ///                 "field_id": 1,
  ///                 "label": "Full Name",
  ///                 "key": "full_name",
  ///                 "type": "TEXT",
  ///                 "field_type": "string",
  ///                 "field_style": "text",
  ///                 "required": true,
  ///                 "options": [],
  ///                 "popup": null,
  ///                 "validation_rules": {
  ///                   "min_length": 2,
  ///                   "max_length": 100
  ///                 }
  ///               }
  ///             ]
  ///           }
  ///         ]
  ///       }
  ///     ]
  ///   }
  /// }
  /// ```
  static Future<ApiForm?> getDynamicRegistrationFields(
      int subCategoryId) async {
    await Future.delayed(_mockDelay);

    // Search all categories for the matching subcategory
    final categories = await getCategories();
    for (final cat in categories) {
      for (final sub in cat.subcategories) {
        if (sub.id == subCategoryId) {
          return sub.primaryForm;
        }
      }
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  MOCK JSON DATA — mirrors exact backend API response structure
  //  These methods return Map<String, dynamic> that the fromJson() factories
  //  will parse. When the real API is ready, replace these with HTTP calls.
  // ═══════════════════════════════════════════════════════════════════════════

  // ── Shared personal info fields (used across all subcategories) ──────────
  static List<Map<String, dynamic>> _personalInfoFieldsJson() => [
        {
          'field_id': 1,
          'label': 'Full Name',
          'key': 'full_name',
          'type': 'TEXT',
          'required': true,
          'options': [],
          'popup': null,
        },
        {
          'field_id': 2,
          'label': 'Mobile Number',
          'key': 'mobile_number',
          'type': 'TEXT',
          'required': true,
          'options': [],
          'popup': null,
        },
      ];

  static Map<String, dynamic> _personalInfoSectionJson() => {
        'section_id': 'personal_info',
        'section_title': 'Personal Info',
        'fields': _personalInfoFieldsJson(),
      };

  // ── Agroforestry ─────────────────────────────────────────────────────────

  static Map<String, dynamic> _agroforestryCategoryJson() {
    final subcategoryNames = [
      'Silvopasture',
      'Alley Cropping',
      'Forest Farming',
      'Riparian Buffers',
      'Windbreaks & Shelterbelts',
      'Multi-strata Systems',
      'Homegardens',
      'Taungya System',
    ];

    return {
      'category_id': 1,
      'category_name': 'Agroforestry',
      'subcategories': _buildSubcategoriesJson(
        names: subcategoryNames,
        baseId: 100,
        geoRequired: true,
      ),
    };
  }

  // ── Soil Carbon ──────────────────────────────────────────────────────────

  static Map<String, dynamic> _soilCarbonCategoryJson() {
    final subcategoryNames = [
      'Cover Cropping',
      'No-till / Reduced Tillage',
      'Rotational Grazing',
      'Compost Application',
      'Biosolids Application',
      'Wetland Restoration',
      'Grassland Management',
    ];

    return {
      'category_id': 2,
      'category_name': 'Soil Carbon',
      'subcategories': _buildSubcategoriesJson(
        names: subcategoryNames,
        baseId: 200,
        geoRequired: true,
      ),
    };
  }

  // ── Biochar ──────────────────────────────────────────────────────────────

  static Map<String, dynamic> _biocharCategoryJson() {
    final subcategoryNames = [
      'Wood Biochar',
      'Crop Residue Biochar',
      'Bamboo Biochar',
      'Municipal Waste Biochar',
      'Co-composting with Biochar',
      'Livestock Manure Biochar',
    ];

    return {
      'category_id': 3,
      'category_name': 'Biochar',
      'subcategories': _buildSubcategoriesJson(
        names: subcategoryNames,
        baseId: 300,
        geoRequired: false,
      ),
    };
  }

  // ── Helper: build subcategory JSON list ───────────────────────────────────

  static List<Map<String, dynamic>> _buildSubcategoriesJson({
    required List<String> names,
    required int baseId,
    required bool geoRequired,
  }) {
    return names.asMap().entries.map((e) {
      final index = e.key;
      final name = e.value;
      return {
        'subcategory_id': baseId + index,
        'subcategory_name': name,
        'forms': [
          {
            'form_id': baseId * 10 + index,
            'form_name': 'Greenated',
            'form_config': {
              'geoLocationRequired': geoRequired,
            },
            'sections': [
              _personalInfoSectionJson(),
            ],
          },
        ],
      };
    }).toList();
  }
}
