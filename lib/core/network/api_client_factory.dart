import '../../config/env_config.dart';
import 'api_client.dart';
import 'interceptor/api_interceptor.dart';
import 'interceptor/auth_interceptor.dart';
import 'interceptor/logging_interceptor.dart';
import 'mock_http_client.dart';
import 'http_client_impl.dart';

/// Factory that creates the correct [ApiClient] based on environment.
///
/// * **Demo mode** → [MockHttpClient] (canned responses, no network).
/// * **Production** → [HttpClientImpl] (real HTTP calls).
///
/// This is the **only place** that knows which concrete client is active.
/// All other code depends on the [ApiClient] abstraction.
///
/// ```dart
/// final ApiClient client = ApiClientFactory.create();
/// ```
class ApiClientFactory {
  ApiClientFactory._();

  /// Creates the appropriate [ApiClient] for the current environment.
  ///
  /// [tokenProvider] — optional callback returning the current bearer token.
  /// Pass `null` while auth is not yet implemented.
  static ApiClient create({String? Function()? tokenProvider}) {
    final List<ApiInterceptor> interceptors = <ApiInterceptor>[
      LoggingInterceptor(),
      if (tokenProvider != null)
        AuthInterceptor(tokenProvider: tokenProvider),
    ];

    if (EnvConfig.isDemoMode) {
      return MockHttpClient(interceptors: interceptors);
    }

    return HttpClientImpl(interceptors: interceptors);
  }
}
