import '../core/network/network.dart';
import '../models/category/category_models.dart';

/// Thin network service that loads the app's category catalogue.
///
/// Wraps the [ApiEndpoints.categories] endpoint, optionally scoping the request
/// to the current user via the injected `userIdProvider`, and decodes the
/// response into a list of [CategoryModel] (each carrying its nested
/// subcategories). It is the lowest layer of the category stack: the
/// `CategoryRepository` calls it and adds caching, and `FormConfigService`
/// exposes the result to the UI.
class CategoryApiService {
  const CategoryApiService({
    required ApiClient apiClient,
    required int? Function() userIdProvider,
  })  : _apiClient = apiClient,
        _userIdProvider = userIdProvider;

  final ApiClient _apiClient;
  final int? Function() _userIdProvider;

  /// Fetches every available category (with its subcategories) from the backend.
  ///
  /// When the injected `userIdProvider` yields a non-null id it is passed as the
  /// `userId` query parameter so the server can scope the catalogue to that user.
  /// Throws [ApiException] when the request fails or returns no data.
  Future<List<CategoryModel>> fetchCategories() async {
    final userId = _userIdProvider();

    final response = await _apiClient.send<List<dynamic>>(
      ApiRequest(
        method: ApiMethod.get,
        path: ApiEndpoints.categories,
        queryParameters:
            userId != null ? {'userId': userId.toString()} : const {},
      ),
      decoder: (raw) => raw is List ? raw : null,
    );

    if (!response.isSuccess || response.data == null) {
      throw ApiException(
        response.message.isEmpty
            ? 'Failed to load categories.'
            : response.message,
        statusCode: response.statusCode,
      );
    }

    return response.data!
        .whereType<Map>()
        .map((json) => CategoryModel.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }
}
