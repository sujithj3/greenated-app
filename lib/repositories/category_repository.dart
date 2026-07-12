import '../models/category/category_models.dart';
import '../services/category_api_service.dart';

/// Contract for accessing the list of project categories.
///
/// Sits between the higher-level services (e.g. `FormConfigService`) and the
/// network layer, so callers depend on this abstraction rather than a concrete
/// data source. The default implementation is [CategoryRepositoryImpl].
abstract class CategoryRepository {
  /// Returns the available [CategoryModel]s, using a cached copy when present.
  /// Pass [forceRefresh] to bypass the cache and re-fetch from the network.
  Future<List<CategoryModel>> fetchCategories({bool forceRefresh = false});

  /// Drops any cached categories so the next fetch hits the network.
  /// Categories are scoped to the signed-in user, so this must be called on
  /// sign-out to avoid serving one user's categories to the next.
  void clearCache();
}

/// Network-backed [CategoryRepository] that fetches via [CategoryApiService]
/// and memoises the result in an in-memory cache.
///
/// The cache is populated on first fetch and reused on subsequent calls until
/// [fetchCategories] is invoked with `forceRefresh: true`, keeping category
/// data stable across screens without repeated network round-trips.
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

  @override
  void clearCache() {
    _cache = null;
  }
}
