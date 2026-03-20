import '../models/category/category_models.dart';
import '../services/category_api_service.dart';

abstract class CategoryRepository {
  Future<List<CategoryModel>> fetchCategories({bool forceRefresh = false});
}

class CategoryRepositoryImpl implements CategoryRepository {
  CategoryRepositoryImpl({required CategoryApiService apiService})
      : _apiService = apiService;

  final CategoryApiService _apiService;

  List<CategoryModel>? _cache;

  @override
  Future<List<CategoryModel>> fetchCategories(
      {bool forceRefresh = false}) async {
    if (!forceRefresh && _cache != null) {
      return _cache!;
    }

    final categories = await _apiService.fetchCategories();
    _cache = List<CategoryModel>.unmodifiable(categories);
    return _cache!;
  }
}
