import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_client.dart';
import 'api_config.dart';
import 'api_exception.dart';
import 'api_method.dart';
import 'api_request.dart';
import 'api_response.dart';
import 'api_status_code.dart';
import 'interceptor/api_interceptor.dart';

/// Production HTTP client that talks to the real backend.
///
/// Features:
/// * Prepends [ApiConfig.versionedBaseUrl] to every request path.
/// * Merges [ApiConfig.defaultHeaders] with per-request headers.
/// * Runs all registered [interceptors] in order.
/// * Maps low-level failures (socket, timeout) to the typed
///   [ApiException] hierarchy.
///
/// ```dart
/// final client = HttpClientImpl(
///   interceptors: [LoggingInterceptor(), AuthInterceptor(...)],
/// );
/// ```
class HttpClientImpl implements ApiClient {
  HttpClientImpl({
    http.Client? httpClient,
    this.interceptors = const <ApiInterceptor>[],
  }) : _http = httpClient ?? http.Client();

  final http.Client _http;
  final List<ApiInterceptor> interceptors;

  @override
  Future<ApiResponse<T>> send<T>(
    ApiRequest request, {
    T? Function(Object? rawData)? decoder,
  }) async {
    // ── 1. Run request interceptors ─────────────────────────────────────
    ApiRequest processed = request;
    for (final ApiInterceptor interceptor in interceptors) {
      processed = interceptor.onRequest(processed);
    }

    try {
      // ── 2. Build the URI ──────────────────────────────────────────────
      final Uri uri = Uri.parse(
        '${ApiConfig.versionedBaseUrl}${processed.path}',
      ).replace(queryParameters: processed.queryParameters.isNotEmpty
          ? processed.queryParameters
          : null);

      // ── 3. Merge headers ──────────────────────────────────────────────
      final Map<String, String> headers = <String, String>{
        ...ApiConfig.defaultHeaders,
        ...processed.headers,
      };

      processed = processed.copyWith(
        path: uri.toString(),
        headers: headers,
      );

      // ── 4. Execute the HTTP call ──────────────────────────────────────
      final http.Response httpResponse = await _executeRequest(
        processed.method,
        uri,
        headers,
        processed.body,
      ).timeout(ApiConfig.receiveTimeout);

      // ── 5. Parse the JSON envelope ────────────────────────────────────
      final Map<String, dynamic> json = _decodeResponseBody(httpResponse);

      // ── 6. Wrap into ApiResponse ──────────────────────────────────────
      ApiResponse<T> apiResponse = ApiResponse<T>.fromJson(
        json,
        dataParser: decoder,
      );

      // ── 7. Run response interceptors ──────────────────────────────────
      for (final ApiInterceptor interceptor in interceptors) {
        apiResponse = interceptor.onResponse<T>(apiResponse, processed);
      }

      // ── 8. Throw typed exceptions for error status codes ──────────────
      _throwIfError(apiResponse);

      return apiResponse;
    } on ApiException {
      rethrow;
    } on SocketException {
      _notifyErrorInterceptors(const NetworkException(), processed);
      throw const NetworkException();
    } on TimeoutException {
      _notifyErrorInterceptors(const RequestTimeoutException(), processed);
      throw const RequestTimeoutException();
    } on FormatException catch (e) {
      final exception = ApiException('Invalid response format: ${e.message}');
      _notifyErrorInterceptors(exception, processed);
      throw exception;
    } catch (e) {
      final exception = ApiException('Unexpected error: $e');
      _notifyErrorInterceptors(exception, processed);
      throw exception;
    }
  }

  /// Dispatches the HTTP call based on the [ApiMethod].
  Future<http.Response> _executeRequest(
    ApiMethod method,
    Uri uri,
    Map<String, String> headers,
    Object? body,
  ) {
    final String? encodedBody =
        body != null ? jsonEncode(body) : null;

    switch (method) {
      case ApiMethod.get:
        return _http.get(uri, headers: headers);
      case ApiMethod.post:
        return _http.post(uri, headers: headers, body: encodedBody);
      case ApiMethod.put:
        return _http.put(uri, headers: headers, body: encodedBody);
      case ApiMethod.patch:
        return _http.patch(uri, headers: headers, body: encodedBody);
      case ApiMethod.delete:
        return _http.delete(uri, headers: headers, body: encodedBody);
    }
  }

  /// Decodes the response body into a JSON map.
  ///
  /// If the body is empty or not valid JSON, a fallback envelope is
  /// constructed from the raw HTTP status code.
  Map<String, dynamic> _decodeResponseBody(http.Response response) {
    if (response.body.isEmpty) {
      return <String, dynamic>{
        'statusCode': response.statusCode,
        'hasError': response.statusCode >= 400,
        'message': '',
        'data': null,
      };
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        // Unwrap { "response": { ... } } wrapper if present.
        final Map<String, dynamic> envelope =
            decoded.containsKey('response') && decoded['response'] is Map
                ? Map<String, dynamic>.from(decoded['response'] as Map)
                : decoded;

        // Ensure statusCode is always present in the envelope.
        return <String, dynamic>{
          'statusCode': envelope['statusCode'] ?? response.statusCode,
          'hasError': envelope['hasError'] ?? (response.statusCode >= 400),
          'message': envelope['message'] ?? '',
          'data': envelope['data'],
        };
      }
    } on FormatException {
      // Fall through to the synthetic envelope below.
    }

    return <String, dynamic>{
      'statusCode': response.statusCode,
      'hasError': response.statusCode >= 400,
      'message': response.body,
      'data': null,
    };
  }

  /// Maps error [ApiResponse]s into the typed exception hierarchy.
  void _throwIfError<T>(ApiResponse<T> response) {
    if (response.isSuccess) return;

    final String msg = response.message;
    switch (response.statusCode) {
      case ApiStatusCode.badRequest:
        throw BadRequestException(msg.isNotEmpty ? msg : 'Bad request.');
      case ApiStatusCode.unauthorized:
        throw UnauthorizedException(
            msg.isNotEmpty ? msg : 'Session expired.');
      case ApiStatusCode.forbidden:
        throw ForbiddenException(msg.isNotEmpty ? msg : 'Forbidden.');
      case ApiStatusCode.notFound:
        throw NotFoundException(
            msg.isNotEmpty ? msg : 'Resource not found.');
      case ApiStatusCode.unprocessableEntity:
        throw ValidationException(
            msg.isNotEmpty ? msg : 'Validation failed.');
      case ApiStatusCode.tooManyRequests:
        throw RateLimitException(msg.isNotEmpty ? msg : 'Rate limited.');
      case ApiStatusCode.internalServerError:
      case ApiStatusCode.badGateway:
      case ApiStatusCode.serviceUnavailable:
      case ApiStatusCode.gatewayTimeout:
        throw ServerException(msg.isNotEmpty ? msg : 'Server error.');
      default:
        throw ApiException(
          msg.isNotEmpty ? msg : 'Request failed.',
          statusCode: response.statusCode,
        );
    }
  }

  void _notifyErrorInterceptors(Object error, ApiRequest request) {
    for (final ApiInterceptor interceptor in interceptors) {
      interceptor.onError(error, request);
    }
  }
}
