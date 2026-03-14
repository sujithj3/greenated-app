import 'api_method.dart';

/// Immutable description of a single API request.
///
/// Contains the HTTP method, path, optional headers, query parameters,
/// and a JSON-serialisable body. The [routeKey] property combines method
/// and path into a single string used for mock-route matching.
///
/// ```dart
/// final request = ApiRequest(
///   method: ApiMethod.get,
///   path: '/categories',
///   queryParameters: {'page': '1'},
/// );
/// ```
class ApiRequest {
  const ApiRequest({
    required this.method,
    required this.path,
    this.headers = const <String, String>{},
    this.queryParameters = const <String, String>{},
    this.body,
  });

  final ApiMethod method;
  final String path;
  final Map<String, String> headers;
  final Map<String, String> queryParameters;
  final Object? body;

  /// A composite key like `"GET /categories"` used for route matching.
  String get routeKey => '${method.value} $path';

  /// Returns a copy with selectively overridden fields.
  ApiRequest copyWith({
    ApiMethod? method,
    String? path,
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
    Object? body,
  }) {
    return ApiRequest(
      method: method ?? this.method,
      path: path ?? this.path,
      headers: headers ?? this.headers,
      queryParameters: queryParameters ?? this.queryParameters,
      body: body ?? this.body,
    );
  }

  @override
  String toString() =>
      'ApiRequest(${method.value} $path, query=$queryParameters, body=$body)';
}
