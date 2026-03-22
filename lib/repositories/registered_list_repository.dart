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
  }) async {
    final request = ApiRequest(
      method: ApiMethod.get,
      path: ApiEndpoints.registeredList(subcategoryId),
      queryParameters: {
        'userId': userId.toString(),
        'page': page.toString(),
        'pageSize': pageSize.toString(),
      },
    );

    final response = await apiClient.send<RegisteredListResponse>(
      request,
      decoder: (rawData) {
        if (rawData is Map<String, dynamic>) {
          return RegisteredListResponse.fromJson(rawData);
        }
        throw Exception('Unexpected response format for RegisteredListResponse');
      },
    );

    if (response.data == null) {
      throw Exception('Failed to fetch data or data is null');
    }

    return response.data!;
  }
}
