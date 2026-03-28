import '../core/network/network.dart';
import '../models/api/api_models.dart';

/// Holds the data returned by [RegistrationFormService.fetchFormDetail].
class FormDetailResult {
  const FormDetailResult({required this.formName, required this.fields});
  final String formName;
  final List<DynamicFieldModel> fields;
}

class RegistrationFormService {
  const RegistrationFormService({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// Submits a new farmer registration to the backend.
  ///
  /// [payload] should be the full `registrationData` map as constructed by
  /// the form screen (contains subcategoryId, registrationDate, fields, etc.).
  ///
  /// Throws [ApiException] on non-success responses or network errors.
  Future<void> submitRegistration(Map<String, dynamic> payload) async {
    final response = await _apiClient.send<Map<String, dynamic>>(
      ApiRequest(
        method: ApiMethod.post,
        path: ApiEndpoints.registerFarmer,
        body: payload,
      ),
      decoder: (raw) {
        if (raw is Map) {
          return Map<String, dynamic>.from(raw);
        }
        return {};
      },
    );

    if (!response.isSuccess) {
      throw ApiException(
        response.message.isNotEmpty
            ? response.message
            : 'Farmer registration failed. Please try again.',
        statusCode: response.statusCode,
      );
    }
  }

  /// Fetches a submitted form with pre-filled field values for display.
  ///
  /// Returns a [FormDetailResult] with the form name and populated fields.
  /// Throws [ApiException] on non-success responses or network errors.
  Future<FormDetailResult> fetchFormDetail(
      int subcategoryId, int submissionId, int userId) async {
    final response = await _apiClient.send<Map<String, dynamic>>(
      ApiRequest(
        method: ApiMethod.get,
        path: ApiEndpoints.formDetail(subcategoryId),
        queryParameters: {
          'submissionId': submissionId.toString(),
          'userId': userId.toString(),
        },
      ),
      decoder: (raw) {
        if (raw is Map) return Map<String, dynamic>.from(raw);
        return null;
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw ApiException(
        response.message.isEmpty
            ? 'Failed to load form detail.'
            : response.message,
        statusCode: response.statusCode,
      );
    }

    final data = _normalizeJsonKeys(response.data!);
    final forms = data['forms'] as List<dynamic>? ?? const [];
    if (forms.isEmpty) {
      return const FormDetailResult(formName: '', fields: []);
    }

    final formJson = forms.first;
    if (formJson is! Map) {
      return const FormDetailResult(formName: '', fields: []);
    }
    final formData = _normalizeJsonKeys(Map<String, dynamic>.from(formJson));
    final formName = formData['formName']?.toString() ?? '';
    final rawFields = formData['fields'] as List<dynamic>? ?? const [];
    final fields = rawFields
        .whereType<Map>()
        .map((f) => DynamicFieldModel.fromJson(Map<String, dynamic>.from(f)))
        .toList();

    return FormDetailResult(formName: formName, fields: fields);
  }

  Future<ApiForm?> fetchRegistrationForm(int subcategoryId) async {
    final response = await _apiClient.send<Map<String, dynamic>>(
      ApiRequest(
        method: ApiMethod.get,
        path: ApiEndpoints.registrationFields(subcategoryId),
      ),
      decoder: (raw) {
        if (raw is Map) {
          return Map<String, dynamic>.from(raw);
        }
        return null;
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw ApiException(
        response.message.isEmpty
            ? 'Failed to load registration fields.'
            : response.message,
        statusCode: response.statusCode,
      );
    }

    final data = _normalizeJsonKeys(response.data!);
    final forms = data['forms'] as List<dynamic>? ?? const [];
    if (forms.isEmpty) {
      return null;
    }

    final formJson = forms.first;
    if (formJson is! Map) {
      return null;
    }
    return ApiForm.fromJson(Map<String, dynamic>.from(formJson));
  }
}

Map<String, dynamic> _normalizeJsonKeys(Map<String, dynamic> json) {
  final normalized = <String, dynamic>{};
  json.forEach((key, value) {
    normalized[_toCamelCase(key)] = value;
  });
  return normalized;
}

String _toCamelCase(String input) {
  if (!input.contains('_')) return input;
  final segments = input.split('_');
  if (segments.isEmpty) return input;
  return segments.first +
      segments
          .skip(1)
          .where((segment) => segment.isNotEmpty)
          .map(
            (segment) => '${segment[0].toUpperCase()}${segment.substring(1)}',
          )
          .join();
}
