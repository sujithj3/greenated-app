import '../core/network/network.dart';
import '../models/api/api_models.dart';

/// Parsed view of a submitted farmer form, as returned by
/// [RegistrationFormService.fetchFormDetail] / [RegistrationFormService.fetchFormEdit].
///
/// Carries the [formName], the pre-filled farmer [fields] ready for display or
/// editing, the optional [farmerDetails] record, any associated [landDetails],
/// and the [resolvedSubmissionId] discovered within the payload (used when
/// editing land submissions).
class FormDetailResult {
  const FormDetailResult({
    required this.formName,
    required this.fields,
    this.farmerDetails,
    this.landDetails = const [],
    this.resolvedSubmissionId,
  });

  final String formName;
  final List<DynamicFieldModel> fields;
  final FarmerDetails? farmerDetails;
  final List<LandDetail> landDetails;
  final int? resolvedSubmissionId;
}

/// Network service for the farmer/land registration workflow.
///
/// Wraps the registration family of [ApiEndpoints] — registering and editing
/// farmers and their land parcels, and reading back their forms — over the
/// injected [ApiClient]. Submission methods POST a `registrationData` payload
/// and throw [ApiException] on failure; the fetch methods return typed
/// [ApiForm] blueprints or pre-filled [FormDetailResult] / [LandFormData]
/// objects. It is the data source behind the registration view models and
/// [FormConfigService].
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

  /// Registers a new land parcel for the farmer identified by [farmerId].
  ///
  /// [payload] is the land form's `registrationData` map.
  /// Throws [ApiException] on non-success responses or network errors.
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

  /// Submits edits to an existing land submission via the `form-land-edit`
  /// endpoint, keyed by [subcategoryId] and [submissionId] for [userId].
  ///
  /// Throws [ApiException] on non-success responses or network errors.
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

  /// Loads the blank registration [ApiForm] definition for [subcategoryId].
  ///
  /// Returns the first form in the response, or null when the subcategory has
  /// no usable form. Throws [ApiException] on non-success responses.
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

  /// Loads the land-form payload ([LandFormData]) for [subcategoryId].
  ///
  /// Throws [ApiException] on non-success responses or when no data is returned.
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

/// Turns a single normalised form JSON object into a [FormDetailResult],
/// preferring the fields under `farmerDetails` and falling back to the
/// top-level `fields`, and parsing any nested `landDetails`.
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
    resolvedSubmissionId: _resolveSubmissionId(formData, landDetails),
  );
}

int? _resolveSubmissionId(
  Map<String, dynamic> formData,
  List<LandDetail> landDetails,
) {
  for (final land in landDetails) {
    final submissionId = land.submissionId;
    if (submissionId != null && submissionId > 0) {
      return submissionId;
    }
  }

  return _findSubmissionId(formData);
}

int? _findSubmissionId(Object? value) {
  if (value is Map) {
    final normalized = _normalizeJsonKeys(Map<String, dynamic>.from(value));
    final direct = _asPositiveInt(normalized['submissionId']);
    if (direct != null) return direct;

    for (final entryValue in normalized.values) {
      final found = _findSubmissionId(entryValue);
      if (found != null) return found;
    }
  } else if (value is List) {
    for (final item in value) {
      final found = _findSubmissionId(item);
      if (found != null) return found;
    }
  }

  return null;
}

int? _asPositiveInt(Object? value) {
  final parsed = switch (value) {
    int() => value,
    num() => value.toInt(),
    String() => int.tryParse(value),
    _ => null,
  };
  return parsed != null && parsed > 0 ? parsed : null;
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
