import '../core/network/network.dart';
import '../models/category/category_models.dart';

class CategoryApiService {
  const CategoryApiService({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<CategoryModel>> fetchCategories() async {
    final response = await _apiClient.send<List<dynamic>>(
      const ApiRequest(
        method: ApiMethod.get,
        path: ApiEndpoints.categories,
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
