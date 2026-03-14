import '../api_request.dart';
import 'api_interceptor.dart';

/// Injects the current auth token into every outgoing request.
///
/// The token is provided via a callback so this interceptor stays
/// decoupled from any specific auth service or storage mechanism.
///
/// ```dart
/// AuthInterceptor(tokenProvider: () => authService.accessToken)
/// ```
class AuthInterceptor extends ApiInterceptor {
  AuthInterceptor({required this.tokenProvider});

  /// Callback that returns the current bearer token, or `null`
  /// if the user is not authenticated.
  final String? Function() tokenProvider;

  @override
  ApiRequest onRequest(ApiRequest request) {
    final String? token = tokenProvider();
    if (token == null || token.isEmpty) {
      return request;
    }
    return request.copyWith(
      headers: <String, String>{
        ...request.headers,
        'Authorization': 'Bearer $token',
      },
    );
  }
}
