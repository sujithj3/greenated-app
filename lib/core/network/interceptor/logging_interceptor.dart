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
      debugPrint('┌── REQUEST ──────────────────────────────────────');
      debugPrint('│ ${request.method.value} ${request.path}');
      if (request.queryParameters.isNotEmpty) {
        debugPrint('│ Query: ${request.queryParameters}');
      }
      if (request.headers.isNotEmpty) {
        debugPrint('│ Headers: ${request.headers}');
      }
      if (request.body != null) {
        debugPrint('│ Body: ${request.body}');
      }
      debugPrint('└─────────────────────────────────────────────────');
    }
    return request;
  }

  @override
  ApiResponse<T> onResponse<T>(ApiResponse<T> response) {
    if (kDebugMode) {
      debugPrint('┌── RESPONSE ─────────────────────────────────────');
      debugPrint('│ Status: ${response.statusCode.code}');
      debugPrint('│ Success: ${response.isSuccess}');
      debugPrint('│ Message: ${response.message}');
      if (response.data != null) {
        final dataStr = response.data.toString();
        // Truncate long data in logs to keep console readable.
        debugPrint(
          '│ Data: ${dataStr.length > 500 ? '${dataStr.substring(0, 500)}…' : dataStr}',
        );
      }
      debugPrint('└─────────────────────────────────────────────────');
    }
    return response;
  }

  @override
  void onError(Object error, ApiRequest request) {
    if (kDebugMode) {
      debugPrint('┌── ERROR ────────────────────────────────────────');
      debugPrint('│ ${request.method.value} ${request.path}');
      debugPrint('│ $error');
      debugPrint('└─────────────────────────────────────────────────');
    }
  }
}
