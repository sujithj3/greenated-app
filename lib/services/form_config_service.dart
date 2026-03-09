import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/api/api_models.dart';
import '../config/env_config.dart';
import 'mock_api_service.dart';

class FormConfigService extends ChangeNotifier {
  static String get _apiUrl => '${EnvConfig.apiBaseUrl}/category-form-config';

  List<ApiCategory> _categories = [];
  bool _isLoading = false;
  String? _error;

  List<ApiCategory> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoaded => _categories.isNotEmpty;

  /// Fetches all categories (with embedded subcategories and forms).
  ///
  /// In demo mode, delegates to [MockApiService.getCategories()].
  /// When the real API is ready, only the demo-mode branch needs removal.
  Future<void> fetchCategories() async {
    if (_categories.isNotEmpty) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      if (EnvConfig.isDemoMode) {
        // ── Mock API call ──────────────────────────────────────────────────
        // TODO: Remove this branch when real backend API is available.
        _categories = await MockApiService.getCategories();
      } else {
        final res = await http.get(Uri.parse(_apiUrl));
        if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        _categories = (body['data'] as List<dynamic>)
            .map((c) => ApiCategory.fromJson(c as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('FormConfigService: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  ApiCategory? getCategoryByName(String name) {
    try {
      return _categories.firstWhere((c) => c.name == name);
    } catch (_) {
      return null;
    }
  }

  List<String> getSubcategoryNames(String categoryName) {
    return getCategoryByName(categoryName)
            ?.subcategories
            .map((s) => s.name)
            .toList() ??
        [];
  }

  List<ApiField> getFields(String categoryName, String subcategoryName) {
    return getCategoryByName(categoryName)
            ?.findSubcategory(subcategoryName)
            ?.primaryForm
            ?.fields ??
        [];
  }

  /// Returns the primary form for the given category + subcategory.
  ApiForm? getForm(String categoryName, String subcategoryName) {
    return getCategoryByName(categoryName)
        ?.findSubcategory(subcategoryName)
        ?.primaryForm;
  }

  // ── Mock API delegate methods ──────────────────────────────────────────────
  // These methods call through to MockApiService in demo mode.
  // When the real API is ready, replace the mock calls with HTTP calls.

  /// Fetches subcategories for a given category ID.
  ///
  /// **Expected real API:** `GET /api/v1/categories/{categoryId}/subcategories`
  /// TODO: Replace MockApiService call with real HTTP request.
  Future<List<ApiSubcategory>> getSubCategoriesByCategoryId(
      int categoryId) async {
    if (EnvConfig.isDemoMode) {
      return MockApiService.getSubCategories(categoryId);
    }
    // Real API call placeholder
    final res = await http.get(
      Uri.parse('${EnvConfig.apiBaseUrl}/categories/$categoryId/subcategories'),
    );
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['data']['subcategories'] as List<dynamic>)
        .map((s) => ApiSubcategory.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  /// Fetches dynamic registration form fields for a given subcategory ID.
  ///
  /// **Expected real API:**
  ///   `GET /api/v1/subcategories/{subCategoryId}/registration-fields`
  /// TODO: Replace MockApiService call with real HTTP request.
  Future<ApiForm?> getDynamicRegistrationFields(int subCategoryId) async {
    if (EnvConfig.isDemoMode) {
      return MockApiService.getDynamicRegistrationFields(subCategoryId);
    }
    // Real API call placeholder
    final res = await http.get(
      Uri.parse(
          '${EnvConfig.apiBaseUrl}/subcategories/$subCategoryId/registration-fields'),
    );
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final formsJson = body['data']['forms'] as List<dynamic>?;
    if (formsJson == null || formsJson.isEmpty) return null;
    return ApiForm.fromJson(formsJson.first as Map<String, dynamic>);
  }
}
