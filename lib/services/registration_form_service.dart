import '../core/network/network.dart';
import '../models/api/api_models.dart';

/// Holds the data returned by [RegistrationFormService.fetchFormDetail].
class FormDetailResult {
  const FormDetailResult({
    required this.formName,
    required this.fields,
    this.farmerDetails,
    this.landDetails = const [],
  });

  final String formName;
  final List<DynamicFieldModel> fields;
  final FarmerDetails? farmerDetails;
  final List<LandDetail> landDetails;
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

  /// Submits an edited farmer registration to the backend.
  ///
  /// POSTs to the `form-edit` endpoint with the same payload structure as
  /// [submitRegistration].
  ///
  /// Throws [ApiException] on non-success responses or network errors.
  Future<void> submitEditForm(int subcategoryId, int farmerId, int userId,
      Map<String, dynamic> payload) async {
    final response = await _apiClient.send<Map<String, dynamic>>(
      ApiRequest(
        method: ApiMethod.post,
        path: ApiEndpoints.formEdit(subcategoryId),
        queryParameters: {
          'farmerId': farmerId.toString(),
          'userId': userId.toString(),
        },
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
            : 'Update registration failed. Please try again.',
        statusCode: response.statusCode,
      );
    }
  }

  Future<void> submitLandRegistration(
      int farmerId, Map<String, dynamic> payload) async {
    final response = await _apiClient.send<Map<String, dynamic>>(
      ApiRequest(
        method: ApiMethod.post,
        path: ApiEndpoints.registerLand,
        queryParameters: {
          'farmerId': farmerId.toString(),
        },
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
            : 'Something went wrong. Please try again.',
        statusCode: response.statusCode,
      );
    }
  }

  Future<void> submitEditLandRegistration({
    required int subcategoryId,
    required int submissionId,
    required int userId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _apiClient.send<Map<String, dynamic>>(
      ApiRequest(
        method: ApiMethod.post,
        path: ApiEndpoints.formLandEdit(subcategoryId),
        queryParameters: {
          'submissionId': submissionId.toString(),
          'userId': userId.toString(),
        },
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
            : 'Something went wrong. Please try again.',
        statusCode: response.statusCode,
      );
    }
  }

  /// Fetches a submitted form with pre-filled field values for display.
  ///
  /// Returns a [FormDetailResult] with the form name and populated fields.
  /// Throws [ApiException] on non-success responses or network errors.
  Future<FormDetailResult> fetchFormDetail(
      int subcategoryId, int farmerId, int userId) async {
    final response = await _apiClient.send<Map<String, dynamic>>(
      ApiRequest(
        method: ApiMethod.get,
        path: ApiEndpoints.formDetail(subcategoryId),
        queryParameters: {
          'farmerId': farmerId.toString(),
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
    return _parseFormDetailResult(formData);
  }

  /// Fetches a submitted form with pre-filled values for editing.
  ///
  /// Uses the `form-edit` endpoint. Returns the same [FormDetailResult]
  /// structure as [fetchFormDetail].
  /// Throws [ApiException] on non-success responses or network errors.
  Future<FormDetailResult> fetchFormEdit(
      int subcategoryId, int farmerId, int userId) async {
    final response = await _apiClient.send<Map<String, dynamic>>(
      ApiRequest(
        method: ApiMethod.get,
        path: ApiEndpoints.formEdit(subcategoryId),
        queryParameters: {
          'farmerId': farmerId.toString(),
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
            ? 'Failed to load edit form data.'
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
    return _parseFormDetailResult(formData);
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

  Future<LandFormData> fetchLandForm(int subcategoryId) async {
    final response = await _apiClient.send<LandFormData>(
      ApiRequest(
        method: ApiMethod.get,
        path: ApiEndpoints.landForm(subcategoryId),
      ),
      decoder: (raw) {
        if (raw is Map) {
          return LandFormData.fromJson(Map<String, dynamic>.from(raw));
        }
        return null;
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw ApiException(
        response.message.isEmpty
            ? 'Failed to load land form.'
            : response.message,
        statusCode: response.statusCode,
      );
    }

    return response.data!;
  }
}

FormDetailResult _parseFormDetailResult(Map<String, dynamic> formData) {
  final formName = formData['formName']?.toString() ?? '';
  final oldRawFields = formData['fields'] as List<dynamic>? ?? const [];
  final oldFields = oldRawFields
      .whereType<Map>()
      .map((field) =>
          DynamicFieldModel.fromJson(Map<String, dynamic>.from(field)))
      .toList();

  final farmerDetails = formData['farmerDetails'] is Map
      ? FarmerDetails.fromJson(
          Map<String, dynamic>.from(formData['farmerDetails'] as Map),
        )
      : null;
  final farmerFields = farmerDetails?.fields.isNotEmpty == true
      ? farmerDetails!.fields
      : oldFields;

  final rawLandDetails = formData['landDetails'] as List<dynamic>? ?? const [];
  final landDetails = rawLandDetails
      .whereType<Map>()
      .map((land) => LandDetail.fromJson(Map<String, dynamic>.from(land)))
      .toList();

  return FormDetailResult(
    formName: formName,
    fields: farmerFields,
    farmerDetails: farmerDetails,
    landDetails: landDetails,
  );
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
