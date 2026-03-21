import 'api_request.dart';
import 'api_response.dart';

/// Abstract contract for all HTTP client implementations.
///
/// Both the real [RobystHttpClient] and [MockHttpClient] implement this
/// interface, which lets the rest of the app remain completely unaware
/// of whether it is talking to a live server or a local mock.
///
/// Usage:
/// ```dart
/// final ApiResponse<Map<String, dynamic>> res = await client.send(
///   ApiRequest(method: ApiMethod.get, path: '/categories'),
///   decoder: (raw) => raw as Map<String, dynamic>,
/// );
/// ```
abstract class ApiClient {
  /// Sends the given [request] and returns a typed [ApiResponse].
  ///
  /// The optional [decoder] callback converts the raw `data` field
  /// from the server's JSON envelope into the desired Dart type [T].
  Future<ApiResponse<T>> send<T>(
    ApiRequest request, {
    T? Function(Object? rawData)? decoder,
  });

  /// Uploads a file as multipart/form-data and returns a typed [ApiResponse].
  ///
  /// [filePath] is the absolute path to the file on disk.
  /// [fileKey] is the form field name for the file (e.g. "file").
  /// [path] is the API endpoint path (relative).
  Future<ApiResponse<T>> uploadFile<T>(
    String path, {
    required String filePath,
    String fileKey = 'file',
    Map<String, String> fields = const {},
    T? Function(Object? rawData)? decoder,
  });
}
