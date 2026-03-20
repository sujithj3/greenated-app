import 'dart:async';

import 'api_client.dart';
import 'api_request.dart';
import 'api_response.dart';
import 'api_status_code.dart';
import 'interceptor/api_interceptor.dart';

class MockHttpClient implements ApiClient {
  MockHttpClient({
    this.latency = const Duration(milliseconds: 600),
    this.interceptors = const <ApiInterceptor>[],
  });

  final Duration latency;
  final List<ApiInterceptor> interceptors;

  @override
  Future<ApiResponse<T>> send<T>(
    ApiRequest request, {
    T? Function(Object? rawData)? decoder,
  }) async {
    ApiRequest processed = request;
    for (final interceptor in interceptors) {
      processed = interceptor.onRequest(processed);
    }

    await Future<void>.delayed(latency);

    final json = _route(processed);
    ApiResponse<T> response = ApiResponse<T>.fromJson(
      json,
      dataParser: decoder,
    );

    for (final interceptor in interceptors) {
      response = interceptor.onResponse<T>(response, processed);
    }

    return response;
  }

  Map<String, dynamic> _route(ApiRequest request) {
    final key = request.routeKey;

    if (key == 'POST login/request-otp') return _mockRequestOtp();
    if (key == 'POST login/verify-otp') return _mockVerifyOtp();
    if (key == 'GET /list-farmers') return _mockGetFarmers();
    if (key == 'POST /register-farmer') return _mockCreateFarmer(request);
    if (request.method.value == 'GET' &&
        RegExp(r'^/farmer/.*$').hasMatch(request.path)) {
      return _mockGetFarmers();
    }

    return _error(
      ApiStatusCode.notFound,
      'Mock route not found for $key.',
    );
  }

  Map<String, dynamic> _mockRequestOtp() {
    return _success(
      message: 'OTP sent successfully.',
      data: <String, dynamic>{
        'verificationId': 'mock-verification-id-12345',
      },
    );
  }

  Map<String, dynamic> _mockVerifyOtp() {
    return _success(
      message: 'OTP verified successfully',
      data: <String, dynamic>{
        'userId': 2,
        'name': 'admin',
        'mobileNumber': '9061108698',
        'createdAt': '2026-02-10T10:00:34.565767',
        'lastLoginAt': DateTime.now().toIso8601String(),
      },
    );
  }

  Map<String, dynamic> _mockGetFarmers() {
    return _success(
      message: 'Farmers fetched successfully.',
      data: <Map<String, dynamic>>[],
    );
  }

  Map<String, dynamic> _mockCreateFarmer(ApiRequest request) {
    return _success(
      statusCode: ApiStatusCode.created,
      message: 'Farmer registered successfully.',
      data: _bodyAsMap(request.body),
    );
  }

  Map<String, dynamic> _success({
    required String message,
    Object? data,
    ApiStatusCode statusCode = ApiStatusCode.ok,
  }) {
    return <String, dynamic>{
      'statusCode': statusCode.code,
      'hasError': false,
      'message': message,
      'data': data,
    };
  }

  Map<String, dynamic> _error(ApiStatusCode statusCode, String message) {
    return <String, dynamic>{
      'statusCode': statusCode.code,
      'hasError': true,
      'message': message,
      'data': null,
    };
  }

  Map<String, dynamic> _bodyAsMap(Object? body) {
    if (body is Map<String, dynamic>) return body;
    if (body is Map) return Map<String, dynamic>.from(body);
    return const <String, dynamic>{};
  }
}
