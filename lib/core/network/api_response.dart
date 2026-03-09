import 'api_status_code.dart';

/// Generic envelope for every API response.
///
/// The backend is expected to return JSON in the shape:
/// ```json
/// {
///   "statusCode": 200,
///   "hasError": false,
///   "message": "Success",
///   "data": { ... }
/// }
/// ```
///
/// Use [fromJson] with an optional [dataParser] callback to deserialise
/// the `data` field into a concrete Dart type.
class ApiResponse<T> {
  const ApiResponse({
    required this.statusCode,
    required this.hasError,
    required this.message,
    this.data,
  });

  final ApiStatusCode statusCode;
  final bool hasError;
  final String message;
  final T? data;

  /// Convenience getter — `true` when the server reports no error
  /// **and** the HTTP status code falls in the 2xx range.
  bool get isSuccess => !hasError && statusCode.isSuccess;

  /// Deserialises a raw JSON map into an [ApiResponse].
  ///
  /// If [dataParser] is supplied it is used to convert the raw `data`
  /// value into [T]; otherwise a direct cast is attempted.
  factory ApiResponse.fromJson(
    Map<String, dynamic> json, {
    T? Function(Object? rawData)? dataParser,
  }) {
    final int rawStatusCode =
        json['statusCode'] is int ? json['statusCode'] as int : 0;
    final Object? rawData = json['data'];

    final T? parsedData;
    if (dataParser != null) {
      parsedData = dataParser(rawData);
    } else if (rawData is T) {
      parsedData = rawData;
    } else {
      parsedData = null;
    }

    return ApiResponse<T>(
      statusCode: ApiStatusCode.fromCode(rawStatusCode),
      hasError: json['hasError'] == true,
      message: (json['message'] as String?) ?? '',
      data: parsedData,
    );
  }

  /// Serialises this response back to a JSON-compatible map.
  Map<String, dynamic> toJson({Object? Function(T value)? dataSerializer}) {
    return <String, dynamic>{
      'statusCode': statusCode.code,
      'hasError': hasError,
      'message': message,
      'data': data == null
          ? null
          : dataSerializer != null
              ? dataSerializer(data as T)
              : data,
    };
  }

  @override
  String toString() =>
      'ApiResponse(status=${statusCode.code}, hasError=$hasError, '
      'message="$message", data=$data)';
}
