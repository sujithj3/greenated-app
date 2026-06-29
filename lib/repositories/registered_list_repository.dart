import '../core/network/api_client.dart';
import '../core/network/api_request.dart';
import '../core/network/api_endpoints.dart';
import '../core/network/api_method.dart';
import '../models/registered_list_response.dart';

abstract class RegisteredListRepository {
  Future<RegisteredListResponse> fetchRegisteredList({
    required int subcategoryId,
    required int userId,
    required int page,
    int pageSize = 10,
    String? search,
  });
}

class RegisteredListRepositoryImpl implements RegisteredListRepository {
  final ApiClient apiClient;

  RegisteredListRepositoryImpl({required this.apiClient});

  @override
  Future<RegisteredListResponse> fetchRegisteredList({
    required int subcategoryId,
    required int userId,
    required int page,
    int pageSize = 10,
    String? search,
  }) async {
    final trimmedSearch = search?.trim();
    final queryParameters = <String, String>{
      'userId': userId.toString(),
      'page': page.toString(),
      'pageSize': pageSize.toString(),
      if (trimmedSearch != null && trimmedSearch.isNotEmpty)
        'search': trimmedSearch,
    };

    final request = ApiRequest(
      method: ApiMethod.get,
      path: ApiEndpoints.registeredList(subcategoryId),
      queryParameters: queryParameters,
    );

    final response = await apiClient.send<RegisteredListResponse>(
      request,
      decoder: (rawData) {
        if (rawData is Map<String, dynamic>) {
          return RegisteredListResponse.fromJson(rawData);
        }
        throw Exception(
            'Unexpected response format for RegisteredListResponse');
      },
    );

    if (response.data == null) {
      throw Exception('Failed to fetch data or data is null');
    }

    return response.data!;
  }
}
