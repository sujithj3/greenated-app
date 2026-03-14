/// Maps common HTTP status codes to named enum values.
///
/// Use [fromCode] to convert a raw integer status code into the
/// corresponding enum value. Unknown codes resolve to [unknown].
enum ApiStatusCode {
  // ── 2xx Success ──
  ok(200),
  created(201),
  accepted(202),
  noContent(204),

  // ── 3xx Redirection ──
  notModified(304),

  // ── 4xx Client Errors ──
  badRequest(400),
  unauthorized(401),
  forbidden(403),
  notFound(404),
  methodNotAllowed(405),
  conflict(409),
  gone(410),
  unprocessableEntity(422),
  tooManyRequests(429),

  // ── 5xx Server Errors ──
  internalServerError(500),
  badGateway(502),
  serviceUnavailable(503),
  gatewayTimeout(504),

  // ── Fallback ──
  unknown(0);

  const ApiStatusCode(this.code);

  final int code;

  /// Returns `true` for any 2xx status code.
  bool get isSuccess => code >= 200 && code < 300;

  /// Returns `true` for any 4xx status code.
  bool get isClientError => code >= 400 && code < 500;

  /// Returns `true` for any 5xx status code.
  bool get isServerError => code >= 500 && code < 600;

  /// Resolves a raw HTTP status code to the matching [ApiStatusCode].
  /// Falls back to [unknown] if no match is found.
  static ApiStatusCode fromCode(int rawCode) {
    for (final ApiStatusCode status in ApiStatusCode.values) {
      if (status.code == rawCode) {
        return status;
      }
    }
    return ApiStatusCode.unknown;
  }
}
