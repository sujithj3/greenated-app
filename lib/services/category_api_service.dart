import '../core/network/network.dart';
import '../models/category/category_models.dart';

class CategoryApiService {
  const CategoryApiService({
    required ApiClient apiClient,
    required int? Function() userIdProvider,
  })  : _apiClient = apiClient,
        _userIdProvider = userIdProvider;

  final ApiClient _apiClient;
  final int? Function() _userIdProvider;

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
