import 'package:flutter/material.dart';

import '../models/api/api_models.dart';
import '../models/category/category_models.dart';
import '../repositories/category_repository.dart';
import 'registration_form_service.dart';

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

  Future<ApiForm?> getDynamicRegistrationFields(int subCategoryId) {
    return _registrationFormService.fetchRegistrationForm(subCategoryId);
  }
}
