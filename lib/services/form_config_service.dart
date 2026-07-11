import 'package:flutter/material.dart';

import '../models/api/api_models.dart';
import '../models/category/category_models.dart';
import '../repositories/category_repository.dart';
import 'registration_form_service.dart';

/// Central store and lookup facade for category/subcategory configuration and
/// the server-driven forms attached to them.
///
/// Loads categories once through [CategoryRepository] (which caches them),
/// caches the resulting [CategoryModel] list in memory, and delegates form
/// definition fetches to [RegistrationFormService]. As a [ChangeNotifier] it
/// exposes observable state — [categories], [isLoading], [error] and
/// [isLoaded] — that the UI and view models listen to, together with
/// synchronous lookups for resolving subcategories and their dynamic forms.
class FormConfigService extends ChangeNotifier {
  FormConfigService({
    required CategoryRepository categoryRepository,
    required RegistrationFormService registrationFormService,
  })  : _categoryRepository = categoryRepository,
        _registrationFormService = registrationFormService;

  final CategoryRepository _categoryRepository;
  final RegistrationFormService _registrationFormService;

  List<CategoryModel> _categories = const [];
  bool _isLoading = false;
  String? _error;

  List<CategoryModel> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoaded => _categories.isNotEmpty;

  /// Loads categories into memory and notifies listeners around the request.
  ///
  /// Skips the fetch when one is already in flight, or when categories are
  /// already cached and [forceRefresh] is false. Failures are captured in
  /// [error] rather than rethrown so the UI can render an error state.
  Future<void> fetchCategories({bool forceRefresh = false}) async {
    if (_isLoading) return;
    if (!forceRefresh && _categories.isNotEmpty) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _categories = await _categoryRepository.fetchCategories(
        forceRefresh: forceRefresh,
      );
    } catch (error) {
      _error = error.toString();
      debugPrint('FormConfigService.fetchCategories error: $error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Returns the cached [CategoryModel] whose name matches [name], or null.
  CategoryModel? getCategoryByName(String name) {
    try {
      return _categories
          .firstWhere((category) => category.categoryName == name);
    } catch (_) {
      return null;
    }
  }

  List<String> getSubcategoryNames(String categoryName) {
    return getCategoryByName(categoryName)
            ?.subcategories
            .map((subcategory) => subcategory.subcategoryName)
            .toList() ??
        const [];
  }

  List<SubcategoryModel> getSubcategories(String categoryName) {
    return getCategoryByName(categoryName)?.subcategories ?? const [];
  }

  /// Resolves the subcategories for [categoryId], loading categories first if
  /// they have not been fetched yet. Returns an empty list when unknown.
  Future<List<SubcategoryModel>> getSubCategoriesByCategoryId(
    int categoryId,
  ) async {
    await fetchCategories();
    final category = _categories.cast<CategoryModel?>().firstWhere(
          (entry) => entry?.categoryId == categoryId,
          orElse: () => null,
        );
    return category?.subcategories ?? const [];
  }

  /// Fetches the dynamic registration [ApiForm] for [subCategoryId] by
  /// delegating to [RegistrationFormService.fetchRegistrationForm].
  Future<ApiForm?> getDynamicRegistrationFields(int subCategoryId) {
    return _registrationFormService.fetchRegistrationForm(subCategoryId);
  }
}
