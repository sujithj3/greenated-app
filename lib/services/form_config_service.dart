import 'package:flutter/material.dart';

import '../core/network/network.dart';
import '../models/api/api_models.dart';

/// Service that fetches and caches category/form configuration.
///
/// Uses [ApiClient] under the hood — in demo mode this resolves to
/// [MockHttpClient]; in production it hits the real backend.
/// Business logic in this class is identical either way.
class FormConfigService extends ChangeNotifier {
  FormConfigService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClientFactory.create();

  final ApiClient _apiClient;

  List<ApiCategory> _categories = [];
  bool _isLoading = false;
  String? _error;

  List<ApiCategory> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoaded => _categories.isNotEmpty;

  /// Fetches all categories (with embedded subcategories and forms).
  Future<void> fetchCategories() async {
    if (_categories.isNotEmpty) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final ApiResponse<List<dynamic>> response =
          await _apiClient.send<List<dynamic>>(
        const ApiRequest(
          method: ApiMethod.get,
          path: ApiEndpoints.categories,
        ),
        decoder: (raw) => raw is List ? raw : null,
      );

      if (!response.isSuccess || response.data == null) {
        throw ApiException(
          response.message.isNotEmpty
              ? response.message
              : 'Failed to load categories.',
          statusCode: response.statusCode,
        );
      }

      _categories = response.data!
          .map((c) => ApiCategory.fromJson(c as Map<String, dynamic>))
          .toList();
    } on ApiException catch (e) {
      _error = e.message;
      debugPrint('FormConfigService: $e');
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

  /// Fetches subcategories for a given category ID.
  Future<List<ApiSubcategory>> getSubCategoriesByCategoryId(
      int categoryId) async {
    final ApiResponse<Map<String, dynamic>> response =
        await _apiClient.send<Map<String, dynamic>>(
      ApiRequest(
        method: ApiMethod.get,
        path: ApiEndpoints.subcategories(categoryId),
      ),
      decoder: (raw) {
        if (raw is Map<String, dynamic>) return raw;
        if (raw is Map) return Map<String, dynamic>.from(raw);
        return null;
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw ApiException(
        response.message.isNotEmpty
            ? response.message
            : 'Failed to load subcategories.',
        statusCode: response.statusCode,
      );
    }

    final subcatsJson =
        response.data!['subcategories'] as List<dynamic>? ?? [];
    return subcatsJson
        .map((s) => ApiSubcategory.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  /// Fetches dynamic registration form fields for a given subcategory ID.
  Future<ApiForm?> getDynamicRegistrationFields(int subCategoryId) async {
    final ApiResponse<Map<String, dynamic>> response =
        await _apiClient.send<Map<String, dynamic>>(
      ApiRequest(
        method: ApiMethod.get,
        path: ApiEndpoints.registrationFields(subCategoryId),
      ),
      decoder: (raw) {
        if (raw is Map<String, dynamic>) return raw;
        if (raw is Map) return Map<String, dynamic>.from(raw);
        return null;
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw ApiException(
        response.message.isNotEmpty
            ? response.message
            : 'Failed to load registration fields.',
        statusCode: response.statusCode,
      );
    }

    final formsJson = response.data!['forms'] as List<dynamic>?;
    if (formsJson == null || formsJson.isEmpty) return null;
    return ApiForm.fromJson(formsJson.first as Map<String, dynamic>);
  }
}
