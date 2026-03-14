import 'api_status_code.dart';

/// Base exception thrown by the networking layer.
///
/// Every API failure surfaces as an [ApiException] (or one of its
/// subclasses), so callers only need to catch this single type
/// and can switch on [runtimeType] for finer-grained handling.
class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode = ApiStatusCode.unknown,
  });

  final String message;
  final ApiStatusCode statusCode;

  @override
  String toString() => 'ApiException($message, statusCode=${statusCode.code})';
}

// ─────────────────────────────────────────────────────────────────────────────
// Network / connectivity errors
// ─────────────────────────────────────────────────────────────────────────────

/// Thrown when the device has no internet connectivity or the server
/// is unreachable (DNS failure, socket exception, etc.).
class NetworkException extends ApiException {
  const NetworkException([
    super.message = 'No internet connection. Please check your network.',
  ]);

  @override
  String toString() => 'NetworkException($message)';
}

/// Thrown when a request exceeds the configured timeout duration.
class RequestTimeoutException extends ApiException {
  const RequestTimeoutException([
    super.message = 'Request timed out. Please try again.',
  ]) : super(statusCode: ApiStatusCode.gatewayTimeout);

  @override
  String toString() => 'RequestTimeoutException($message)';
}

// ─────────────────────────────────────────────────────────────────────────────
// Client errors (4xx)
// ─────────────────────────────────────────────────────────────────────────────

/// 400 – The request payload was malformed or contained invalid data.
class BadRequestException extends ApiException {
  const BadRequestException([
    super.message = 'Invalid request. Please check your input.',
  ]) : super(statusCode: ApiStatusCode.badRequest);

  @override
  String toString() => 'BadRequestException($message)';
}

/// 401 – The user's session has expired or credentials are invalid.
class UnauthorizedException extends ApiException {
  const UnauthorizedException([
    super.message = 'Session expired. Please log in again.',
  ]) : super(statusCode: ApiStatusCode.unauthorized);

  @override
  String toString() => 'UnauthorizedException($message)';
}

/// 403 – The authenticated user lacks permission for this operation.
class ForbiddenException extends ApiException {
  const ForbiddenException([
    super.message = 'You do not have permission to perform this action.',
  ]) : super(statusCode: ApiStatusCode.forbidden);

  @override
  String toString() => 'ForbiddenException($message)';
}

/// 404 – The requested resource could not be found.
class NotFoundException extends ApiException {
  const NotFoundException([
    super.message = 'The requested resource was not found.',
  ]) : super(statusCode: ApiStatusCode.notFound);

  @override
  String toString() => 'NotFoundException($message)';
}

/// 422 – The server understood the request but could not process
/// the contained data (e.g. validation failures).
class ValidationException extends ApiException {
  const ValidationException([
    super.message = 'Validation failed. Please check your input.',
    this.errors = const <String, List<String>>{},
  ]) : super(statusCode: ApiStatusCode.unprocessableEntity);

  /// Per-field validation errors, e.g. `{'email': ['already taken']}`.
  final Map<String, List<String>> errors;

  @override
  String toString() => 'ValidationException($message, errors=$errors)';
}

/// 429 – Too many requests in a given amount of time.
class RateLimitException extends ApiException {
  const RateLimitException([
    super.message = 'Too many requests. Please wait and try again.',
  ]) : super(statusCode: ApiStatusCode.tooManyRequests);

  @override
  String toString() => 'RateLimitException($message)';
}

// ─────────────────────────────────────────────────────────────────────────────
// Server errors (5xx)
// ─────────────────────────────────────────────────────────────────────────────

/// 500+ – An unexpected error occurred on the server side.
class ServerException extends ApiException {
  const ServerException([
    super.message = 'Something went wrong. Please try again later.',
  ]) : super(statusCode: ApiStatusCode.internalServerError);

  @override
  String toString() => 'ServerException($message)';
}
