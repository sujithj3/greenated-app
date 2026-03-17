import 'dart:async';

import 'api_client.dart';
import 'api_request.dart';
import 'api_response.dart';
import 'api_status_code.dart';
import 'interceptor/api_interceptor.dart';

/// Mock implementation of [ApiClient] used during development.
///
/// Every route is matched by its [ApiRequest.routeKey] (e.g. `"GET /categories"`)
/// and returns a canned JSON envelope after a configurable [latency].
///
/// When the real backend is ready, simply swap [MockHttpClient] for
/// [RobystHttpClient] in [ApiClientFactory] — no other code changes needed.
class MockHttpClient implements ApiClient {
  MockHttpClient({
    this.latency = const Duration(milliseconds: 600),
    this.interceptors = const <ApiInterceptor>[],
  });

  final Duration latency;
  final List<ApiInterceptor> interceptors;

  @override
  Future<ApiResponse<T>> send<T>(
    ApiRequest request, {
    T? Function(Object? rawData)? decoder,
  }) async {
    // Run request interceptors (for logging etc.)
    ApiRequest processed = request;
    for (final ApiInterceptor interceptor in interceptors) {
      processed = interceptor.onRequest(processed);
    }

    // Simulate network latency
    await Future<void>.delayed(latency);

    final Map<String, dynamic> json = _route(processed);

    ApiResponse<T> response = ApiResponse<T>.fromJson(
      json,
      dataParser: decoder,
    );

    // Run response interceptors
    for (final ApiInterceptor interceptor in interceptors) {
      response = interceptor.onResponse<T>(response);
    }

    return response;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Route matching — add new mock routes here
  // ═══════════════════════════════════════════════════════════════════════════

  Map<String, dynamic> _route(ApiRequest request) {
    // Match on the composite key "METHOD /path".
    // For paths with dynamic segments, strip the ID and match a pattern.
    final String key = request.routeKey;

    // ── Auth ──
    if (key == 'POST /auth/request-otp') return _mockRequestOtp(request);
    if (key == 'POST /auth/verify-otp') return _mockVerifyOtp(request);

    // ── Categories ──
    if (key == 'GET /categories') return _mockGetCategories();

    // ── Subcategories (dynamic path) ──
    if (request.method.value == 'GET' &&
        RegExp(r'^/categories/\d+/subcategories$').hasMatch(request.path)) {
      final int categoryId = _extractId(request.path, segment: 'categories');
      return _mockGetSubcategories(categoryId);
    }

    // ── Registration fields (dynamic path) ──
    if (request.method.value == 'GET' &&
        RegExp(r'^/subcategories/\d+/registration-fields$')
            .hasMatch(request.path)) {
      final int subcategoryId =
          _extractId(request.path, segment: 'subcategories');
      return _mockGetRegistrationFields(subcategoryId);
    }

    // ── Farmers ──
    if (key == 'GET /list-farmers') return _mockGetFarmers();
    if (key == 'POST /register-farmer') return _mockCreateFarmer(request);
    if (request.method.value == 'GET' &&
        RegExp(r'^/farmer/.*$').hasMatch(request.path)) {
      return _mockGetFarmers(); // Return same list for now
    }

    // ── Fallback ──
    return _error(
      ApiStatusCode.notFound,
      'Mock route not found for $key.',
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Mock route handlers
  // ═══════════════════════════════════════════════════════════════════════════

  // ── Auth ────────────────────────────────────────────────────────────────

  Map<String, dynamic> _mockRequestOtp(ApiRequest request) {
    final Map<String, dynamic> body = _bodyAsMap(request.body);
    final String phone =
        _digitsOnly((body['phoneNumber'] as String?) ?? '');
    if (phone.length < 10) {
      return _error(
        ApiStatusCode.badRequest,
        'Please enter a valid phone number.',
      );
    }
    return _success(message: 'OTP sent successfully.');
  }

  Map<String, dynamic> _mockVerifyOtp(ApiRequest request) {
    final Map<String, dynamic> body = _bodyAsMap(request.body);
    final String paramPhone = (body['phoneNumber'] as String?) ?? '+919876543210';
    final String phone = _digitsOnly(paramPhone).isEmpty ? '+919876543210' : paramPhone;
    final String otp =
        _digitsOnly((body['otpCode'] as String?) ?? '');
    if (otp.length != 6) {
      return _error(
        ApiStatusCode.unprocessableEntity,
        'OTP must be 6 digits.',
      );
    }
    if (otp != '123456') {
      return _error(
        ApiStatusCode.unauthorized,
        'Invalid OTP. Use 123456 for demo.',
      );
    }
    return _success(
      message: 'OTP verified.',
      data: <String, dynamic>{
        'token': 'mock-jwt-token-abc123',
        'refreshToken': 'mock-refresh-token-xyz789',
        'user': <String, dynamic>{
          'userId': 'demo-user-123',
          'fullName': 'Demo User',
          'phoneNumber': phone,
        },
      },
    );
  }

  // ── Categories ──────────────────────────────────────────────────────────

  Map<String, dynamic> _mockGetCategories() {
    return _success(
      message: 'Categories fetched successfully.',
      data: <Map<String, dynamic>>[
        _agroforestryCategoryJson(),
        _soilCarbonCategoryJson(),
        _biocharCategoryJson(),
      ],
    );
  }

  Map<String, dynamic> _mockGetSubcategories(int categoryId) {
    final Map<String, dynamic>? category = <Map<String, dynamic>>[
      _agroforestryCategoryJson(),
      _soilCarbonCategoryJson(),
      _biocharCategoryJson(),
    ].cast<Map<String, dynamic>?>().firstWhere(
          (c) => c!['category_id'] == categoryId,
          orElse: () => null,
        );

    if (category == null) {
      return _error(ApiStatusCode.notFound, 'Category not found.');
    }

    return _success(
      message: 'Subcategories fetched successfully.',
      data: <String, dynamic>{
        'category_id': categoryId,
        'category_name': category['category_name'],
        'subcategories': category['subcategories'],
      },
    );
  }

  Map<String, dynamic> _mockGetRegistrationFields(int subcategoryId) {
    // Search all categories for the matching subcategory
    for (final cat in <Map<String, dynamic>>[
      _agroforestryCategoryJson(),
      _soilCarbonCategoryJson(),
      _biocharCategoryJson(),
    ]) {
      for (final sub
          in (cat['subcategories'] as List<Map<String, dynamic>>)) {
        if (sub['subcategory_id'] == subcategoryId) {
          return _success(
            message: 'Registration fields fetched successfully.',
            data: <String, dynamic>{
              'subcategory_id': subcategoryId,
              'subcategory_name': sub['subcategory_name'],
              'forms': sub['forms'],
            },
          );
        }
      }
    }
    return _error(ApiStatusCode.notFound, 'Subcategory not found.');
  }

  // ── Farmers ─────────────────────────────────────────────────────────────

  Map<String, dynamic> _mockGetFarmers() {
    return _success(
      message: 'Farmers fetched successfully.',
      data: <Map<String, dynamic>>[],
    );
  }

  Map<String, dynamic> _mockCreateFarmer(ApiRequest request) {
    return _success(
      statusCode: ApiStatusCode.created,
      message: 'Farmer registered successfully.',
      data: _bodyAsMap(request.body),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Mock data — mirrors the exact backend response structure
  // ═══════════════════════════════════════════════════════════════════════════

  static List<Map<String, dynamic>> _personalInfoFieldsJson() => [
        {
          'field_id': 1,
          'label': 'Full Name',
          'key': 'fullName',
          'field_type': 'STRING', 'field_style': 'text',
          'required': true,
          'options': <dynamic>[],
        },
        {
          'field_id': 2,
          'label': 'Mobile Number',
          'key': 'mobileNumber',
          'field_type': 'STRING', 'field_style': 'text',
          'required': true,
          'options': <dynamic>[],
        },
      ];

  static List<Map<String, dynamic>> _agroforestryExtraFieldsJson() => [
        {
          'field_id': 101,
          'label': 'Tree Species',
          'key': 'treeSpecies',
          'field_type': 'STRING', 'field_style': 'text',
          'required': true,
          'options': <dynamic>[],
        },
        {
          'field_id': 102,
          'label': 'Estimated Tree Count',
          'key': 'treeCount',
          'field_type': 'INT', 'field_style': 'number',
          'required': true,
          'options': <dynamic>[],
        },
        {
          'field_id': 103,
          'label': 'Tree Details',
          'key': 'treeDetails',
          'field_type': 'DICT', 'field_style': 'popup_form',
          'required': false,
          'options': <Map<String, dynamic>>[
            {
              'field_id': 1031,
              'label': 'Species Name',
              'key': 'speciesName',
              'field_type': 'STRING', 'field_style': 'text',
              'required': true,
              'options': <dynamic>[],
            },
            {
              'field_id': 1032,
              'label': 'Age (years)',
              'key': 'ageYears',
              'field_type': 'INT', 'field_style': 'number',
              'required': false,
              'options': <dynamic>[],
            },
            {
              'field_id': 1033,
              'label': 'Health Status',
              'key': 'healthStatus',
              'field_type': 'STRING', 'field_style': 'dropdown',
              'required': false,
              'options': <Map<String, dynamic>>[
                {'label': 'Healthy', 'value': 'Healthy'},
                {'label': 'Moderate', 'value': 'Moderate'},
                {'label': 'Poor', 'value': 'Poor'},
              ],
            },
          ],
        },
      ];

  static List<Map<String, dynamic>> _soilCarbonExtraFieldsJson() => [
        {
          'field_id': 201,
          'label': 'Soil Type',
          'key': 'soilType',
          'field_type': 'STRING', 'field_style': 'dropdown',
          'required': true,
          'options': [
            {'label': 'Clay', 'value': 'Clay'},
            {'label': 'Sandy', 'value': 'Sandy'},
            {'label': 'Loam', 'value': 'Loam'},
            {'label': 'Silt', 'value': 'Silt'},
          ],
        },
        {
          'field_id': 202,
          'label': 'Tillage Frequency (per year)',
          'key': 'tillageFrequency',
          'field_type': 'INT', 'field_style': 'number',
          'required': false,
          'options': <dynamic>[],
        },
      ];

  static List<Map<String, dynamic>> _biocharExtraFieldsJson() => [
        {
          'field_id': 301,
          'label': 'Biomass Source',
          'key': 'biomassSource',
          'field_type': 'STRING', 'field_style': 'text',
          'required': true,
          'options': <dynamic>[],
        },
        {
          'field_id': 302,
          'label': 'Production Method',
          'key': 'productionMethod',
          'field_type': 'STRING', 'field_style': 'dropdown',
          'required': true,
          'options': [
            {'label': 'Kon Tiki Kiln', 'value': 'Kon Tiki Kiln'},
            {'label': 'Flame Curtain', 'value': 'Flame Curtain'},
            {'label': 'Gasifier', 'value': 'Gasifier'},
            {'label': 'Other', 'value': 'Other'},
          ],
        },
      ];

  static Map<String, dynamic> _agroforestryCategoryJson() {
    return {
      'category_id': 1,
      'category_name': 'Agroforestry',
      'subcategories': _buildSubcategoriesJson(
        names: [
          'Silvopasture',
          'Alley Cropping',
          'Forest Farming',
          'Riparian Buffers',
          'Windbreaks & Shelterbelts',
          'Multi-strata Systems',
          'Homegardens',
          'Taungya System',
        ],
        baseId: 100,
        geoRequired: true,
        extraFields: _agroforestryExtraFieldsJson(),
      ),
    };
  }

  static Map<String, dynamic> _soilCarbonCategoryJson() {
    return {
      'category_id': 2,
      'category_name': 'Soil Carbon',
      'subcategories': _buildSubcategoriesJson(
        names: [
          'Cover Cropping',
          'No-till / Reduced Tillage',
          'Rotational Grazing',
          'Compost Application',
          'Biosolids Application',
          'Wetland Restoration',
          'Grassland Management',
        ],
        baseId: 200,
        geoRequired: true,
        extraFields: _soilCarbonExtraFieldsJson(),
      ),
    };
  }

  static Map<String, dynamic> _biocharCategoryJson() {
    return {
      'category_id': 3,
      'category_name': 'Biochar',
      'subcategories': _buildSubcategoriesJson(
        names: [
          'Wood Biochar',
          'Crop Residue Biochar',
          'Bamboo Biochar',
          'Municipal Waste Biochar',
          'Co-composting with Biochar',
          'Livestock Manure Biochar',
        ],
        baseId: 300,
        geoRequired: false,
        extraFields: _biocharExtraFieldsJson(),
      ),
    };
  }

  static List<Map<String, dynamic>> _buildSubcategoriesJson({
    required List<String> names,
    required int baseId,
    required bool geoRequired,
    List<Map<String, dynamic>> extraFields = const [],
  }) {
    return names.asMap().entries.map((e) {
      final index = e.key;
      final name = e.value;
      return <String, dynamic>{
        'subcategory_id': baseId + index,
        'subcategory_name': name,
        'forms': <Map<String, dynamic>>[
          {
            'form_id': baseId * 10 + index,
            'form_name': 'Greenated',
            'geoLocationRequired': geoRequired,
            'fields': <Map<String, dynamic>>[
              ..._personalInfoFieldsJson(),
              ...extraFields,
            ],
          },
        ],
      };
    }).toList();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Envelope helpers
  // ═══════════════════════════════════════════════════════════════════════════

  Map<String, dynamic> _success({
    required String message,
    Object? data,
    ApiStatusCode statusCode = ApiStatusCode.ok,
  }) {
    return <String, dynamic>{
      'statusCode': statusCode.code,
      'hasError': false,
      'message': message,
      'data': data,
    };
  }

  Map<String, dynamic> _error(ApiStatusCode statusCode, String message) {
    return <String, dynamic>{
      'statusCode': statusCode.code,
      'hasError': true,
      'message': message,
      'data': null,
    };
  }

  Map<String, dynamic> _bodyAsMap(Object? body) {
    if (body is Map<String, dynamic>) return body;
    if (body is Map) return Map<String, dynamic>.from(body);
    return const <String, dynamic>{};
  }

  String _digitsOnly(String value) => value.replaceAll(RegExp(r'\D'), '');

  /// Extracts a numeric ID from a path segment.
  /// e.g. `/categories/42/subcategories` with segment `categories` → 42.
  int _extractId(String path, {required String segment}) {
    final parts = path.split('/');
    final segIndex = parts.indexOf(segment);
    if (segIndex >= 0 && segIndex + 1 < parts.length) {
      return int.tryParse(parts[segIndex + 1]) ?? 0;
    }
    return 0;
  }
}
