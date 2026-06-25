import 'package:flutter/foundation.dart';

import '../api_request.dart';
import '../api_response.dart';
import 'api_interceptor.dart';

/// Logs every outgoing request and incoming response to the debug console.
///
/// Only active in debug mode — production builds skip logging entirely.
class LoggingInterceptor extends ApiInterceptor {
  @override
  ApiRequest onRequest(ApiRequest request) {
    if (kDebugMode) {
      debugPrint(
          '🚀 [API Request Started] ${request.method.value} ${request.path}');
    }
    return request;
  }

  @override
  ApiResponse<T> onResponse<T>(ApiResponse<T> response, ApiRequest request) {
    if (kDebugMode) {
      debugPrint(
          '🏁 [API Call Completed] ${request.method.value} ${request.path}');
    }
    return response;
  }

  @override
  void onError(Object error, ApiRequest request) {
    if (kDebugMode) {
      debugPrint('❌ [API Error]');
      debugPrint('${request.method.value} ${request.path}');
      debugPrint(error.toString());
    }
  }
}
