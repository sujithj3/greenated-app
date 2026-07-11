import '../core/network/api_client.dart';
import '../core/network/api_request.dart';
import '../core/network/api_endpoints.dart';
import '../core/network/api_method.dart';
import '../models/registered_list_response.dart';

/// Contract for reading a paginated, optionally searchable list of registered
/// farmers for a given subcategory.
///
/// Abstracts the registered-list data source so view models depend on this
/// interface rather than the network directly. The default implementation is
/// [RegisteredListRepositoryImpl].
abstract class RegisteredListRepository {
  /// Fetches a single page of registered farmers under [subcategoryId] for the
  /// current [userId].
  ///
  /// [page] is 1-based and [pageSize] caps the rows per page; an optional
  /// [search] term filters results server-side. Returns the page rows together
  /// with pagination metadata as a [RegisteredListResponse].
  Future<RegisteredListResponse> fetchRegisteredList({
    required int subcategoryId,
    required int userId,
    required int page,
    int pageSize = 10,
    String? search,
  });
}

/// [ApiClient]-backed [RegisteredListRepository].
///
/// Builds the paginated GET request (attaching the search term only when
/// non-empty), decodes the payload into a [RegisteredListResponse], and throws
/// when the response body is missing or malformed.
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
