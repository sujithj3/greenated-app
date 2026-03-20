import '../api_request.dart';
import '../api_response.dart';

/// Contract for request/response interceptors.
///
/// Interceptors are executed in order:
/// 1. [onRequest]  — called **before** the HTTP call is made.
/// 2. [onResponse] — called **after** a successful response is received.
/// 3. [onError]    — called when the request throws an exception.
///
/// Return the (possibly modified) request / response from each hook.
abstract class ApiInterceptor {
  /// Intercept and optionally modify the outgoing [request].
  ApiRequest onRequest(ApiRequest request) => request;

  /// Intercept and optionally modify the incoming [response].
  ApiResponse<T> onResponse<T>(ApiResponse<T> response, ApiRequest request) => response;

  /// Called when an error occurs during the request lifecycle.
  /// Re-throw or return a recovery response.
  void onError(Object error, ApiRequest request) {}
}
