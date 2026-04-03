import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_method.dart';
import '../../core/network/api_request.dart';
import '../../models/api/api_models.dart';
import '../../services/auth_service.dart';
import '../../services/image_upload_service.dart'
    show ImageUploadService, ImageUploadResult;
import '../../services/registration_form_service.dart';

/// ViewModel for the Edit Farmer Details flow.
///
/// Maintains independent state from the create and detail view models.
/// Fetches prefilled form data via the `form-edit` GET endpoint and
/// exposes it for rendering in [EditFarmerDetailsView].
///
/// Dependent-dropdown fetching (e.g. state → district) is supported but
/// only triggers on **user-initiated** field changes — NOT on initial load,
/// because the API already returns the correct pre-resolved options.
class EditFarmerDetailsViewModel extends ChangeNotifier {
  EditFarmerDetailsViewModel({
    required RegistrationFormService service,
    required AuthService authService,
    required ApiClient apiClient,
    required ImageUploadService imageUploadService,
  })  : _service = service,
        _authService = authService,
        _apiClient = apiClient,
        _imageUploadService = imageUploadService;

  final RegistrationFormService _service;
  final AuthService _authService;
  final ApiClient _apiClient;
  final ImageUploadService _imageUploadService;

  // ── State ────────────────────────────────────────────────────────────────
  bool isLoading = false;
  bool isSaving = false;
  String? error;
  String formName = '';
  List<DynamicFieldModel> fields = [];

  /// Guards dependency handling: stays `false` until the initial load
  /// completes, so prefilled values don't trigger cascading API calls.
  bool _userInteractionEnabled = false;

  /// Tracks per-field upload state for camera fields (key → isUploading).
  final Map<String, bool> _uploadingFields = {};

  /// Whether a specific camera field is currently uploading.
  bool isFieldUploading(String key) => _uploadingFields[key] ?? false;

  /// Whether a specific dependent dropdown field is currently loading.
  bool isFieldLoadingOptions(String key) {
    final idx = fields.indexWhere((df) => df.field.key == key);
    return idx != -1 && fields[idx].isLoadingOptions;
  }

  /// Fetches the edit form data for a given submission.
  ///
  /// Calls the GET `form-edit` endpoint with [subcategoryId], [submissionId],
  /// and the authenticated user's ID.
  Future<void> loadEditForm({
    required int subcategoryId,
    required int submissionId,
  }) async {
    final userId = _authService.userId;
    if (userId == null) {
      error = 'User not authenticated.';
      notifyListeners();
      return;
    }

    _userInteractionEnabled = false;
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final result =
          await _service.fetchFormEdit(subcategoryId, submissionId, userId);
      formName = result.formName;
      fields = result.fields;
    } catch (e) {
      error = e.toString();
      fields = [];
    } finally {
      isLoading = false;
      // Enable dependency handling AFTER the initial load finishes.
      _userInteractionEnabled = true;
      notifyListeners();
    }
  }

  /// Whether a field should be visible based on its showWhen condition.
  bool isFieldVisible(DynamicFieldModel df) => shouldShowField(df, fields);

  /// Updates a dynamic field value by key.
  ///
  /// When called after the initial load (i.e. user-initiated), it triggers
  /// dependent dropdown fetching for any child fields with a `dataSource`.
  void updateFieldValue(String key, dynamic value) {
    final idx = fields.indexWhere((df) => df.field.key == key);
    if (idx != -1) {
      fields[idx].value = value;
      notifyListeners();

      // Only fire dependency handling on user-initiated changes.
      if (_userInteractionEnabled) {
        _handleDependencyChange(key);
      }
    }
  }

  // ── Camera upload ─────────────────────────────────────────────────────────

  /// Uploads a captured image for a camera-type dynamic field.
  ///
  /// Returns the [ImageUploadResult] on success, or null on failure.
  Future<ImageUploadResult?> uploadCameraImage(
      String fieldKey, String localFilePath) async {
    _uploadingFields[fieldKey] = true;
    notifyListeners();

    try {
      final result = await _imageUploadService.uploadImage(localFilePath);
      final idx = fields.indexWhere((df) => df.field.key == fieldKey);
      if (idx != -1) {
        fields[idx].value = result.imagePath;
        fields[idx].previewUrl = result.previewUrl;
        notifyListeners();
      }
      return result;
    } catch (e) {
      debugPrint('Image upload failed for field "$fieldKey": $e');
      return null;
    } finally {
      _uploadingFields[fieldKey] = false;
      notifyListeners();
    }
  }

  /// Clears the uploaded image for a camera-type dynamic field.
  void clearCameraImage(String fieldKey) {
    final idx = fields.indexWhere((df) => df.field.key == fieldKey);
    if (idx != -1) {
      fields[idx].value = null;
      fields[idx].previewUrl = null;
      notifyListeners();
    }
  }

  /// Uploads an image and tracks uploading state without updating [fields].
  /// Used by popup forms whose subfields live in a local copy, not in [fields].
  /// The caller is responsible for applying the result to their own field model.
  Future<ImageUploadResult?> uploadImageOnly(
      String fieldKey, String localFilePath) async {
    _uploadingFields[fieldKey] = true;
    notifyListeners();
    try {
      return await _imageUploadService.uploadImage(localFilePath);
    } catch (e) {
      debugPrint('Image upload failed for field "$fieldKey": $e');
      return null;
    } finally {
      _uploadingFields[fieldKey] = false;
      notifyListeners();
    }
  }

  // ── Save (POST edit) ──────────────────────────────────────────────────────

  /// Submits the edited registration.
  ///
  /// [textValues] is a map of key → current text for text/number/date fields,
  /// passed from the View's TextEditingControllers.
  /// [subcategoryId] and [submissionId] identify the submission being updated.
  ///
  /// Returns true on success, throws on API error.
  Future<bool> save({
    required Map<String, String> textValues,
    required int subcategoryId,
    required int submissionId,
  }) async {
    // Apply text values from controllers into fields; null out hidden fields
    for (final df in fields) {
      if (!isFieldVisible(df)) {
        df.value = null;
        df.previewUrl = null;
        continue;
      }
      if (textValues.containsKey(df.field.key)) {
        final text = textValues[df.field.key]!.trim();
        df.value = text.isNotEmpty ? text : null;
      }
    }

    isSaving = true;
    notifyListeners();

    final List<dynamic> serializedFields =
        fields.map((e) => e.toJson()).toList();

    final submissionPayload = <String, dynamic>{
      'registrationData': <String, dynamic>{
        'subcategoryId': subcategoryId,
        'submissionId': submissionId,
        'registrationDate': DateTime.now().toIso8601String(),
        'status': 'Active',
        'userId': _authService.userId,
        'fields': serializedFields,
      },
    };

    final prettyJson =
        const JsonEncoder.withIndent('  ').convert(submissionPayload);
    debugPrint('=== SUBMITTING EDIT REGISTRATION ===');
    debugPrint(prettyJson);
    debugPrint('====================================');

    try {
      await _service.submitEditForm(
          subcategoryId, submissionId, _authService.userId!, submissionPayload);
      debugPrint(
          '=== EDIT REGISTRATION RESULT === action=update_farmer success=true');
      return true;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  /// Retry a failed dependent-options fetch for [fieldKey].
  Future<void> retryFetchOptions(String fieldKey) async {
    final idx = fields.indexWhere((df) => df.field.key == fieldKey);
    if (idx == -1) return;
    final df = fields[idx];
    if (df.field.dataSource == null || df.field.dependsOn == null) return;
    await _handleDependencyChange(df.field.dependsOn!);
  }

  // ── Dependency handling (ported from FarmerFormViewModel) ────────────────

  /// Resolves template params using values from [fieldList] (defaults to [fields]).
  Map<String, dynamic> _resolveParams(Map<String, String> templates,
      [List<DynamicFieldModel>? fieldList]) {
    final source = fieldList ?? fields;
    final resolved = <String, dynamic>{};
    for (final entry in templates.entries) {
      final template = entry.value;
      String val = '';
      if (template.startsWith(r'$')) {
        final ref = template.substring(1);
        final dotIdx = ref.indexOf('.');
        final fieldKey = dotIdx > 0 ? ref.substring(0, dotIdx) : ref;
        final idx = source.indexWhere((df) => df.field.key == fieldKey);
        val = idx != -1 ? (source[idx].value?.toString() ?? '') : '';
      } else {
        val = template;
      }

      final parsedInt = int.tryParse(val);
      resolved[entry.key] = parsedInt ?? val;
    }
    return resolved;
  }

  /// Resets all dependents of [parentKey] within [fieldList] (defaults to [fields]).
  void _resetDependents(String parentKey,
      [List<DynamicFieldModel>? fieldList]) {
    final source = fieldList ?? fields;
    for (final df in source) {
      if (df.field.dependsOn == parentKey) {
        df.value = null;
        df.previewUrl = null;
        df.resolvedOptions = df.field.options;
        df.isLoadingOptions = false;
        df.optionsError = null;
        df.incrementFetchGeneration();
        _resetDependents(df.field.key, fieldList);
      }
    }
  }

  Future<void> _handleDependencyChange(String changedKey) async {
    _resetDependents(changedKey);
    notifyListeners();

    final directDependents = fields
        .where((df) =>
            df.field.dependsOn == changedKey && df.field.dataSource != null)
        .toList();

    for (final df in directDependents) {
      final resolved = _resolveParams(df.field.dataSource!.params);
      if (resolved.values.any((v) => v.toString().isEmpty)) continue;

      df.isLoadingOptions = true;
      notifyListeners();

      final generation = df.fetchGeneration;
      try {
        final options =
            await _fetchDependentOptions(df.field.dataSource!, resolved);
        if (df.fetchGeneration != generation) continue;
        df.resolvedOptions = options;
        df.optionsError = null;
      } catch (_) {
        if (df.fetchGeneration != generation) continue;
        df.optionsError = 'Failed to load options';
        df.resolvedOptions = [];
      } finally {
        if (df.fetchGeneration == generation) {
          df.isLoadingOptions = false;
          notifyListeners();
        }
      }
    }
  }

  /// Resolves dependent dropdown options for subfields within a popup form.
  /// [changedKey] is the key of the field whose value changed.
  /// [fieldList] is the popup's local copy of [DynamicFieldModel] list.
  Future<void> handleSubfieldDependencyChange(
      String changedKey, List<DynamicFieldModel> fieldList) async {
    _resetDependents(changedKey, fieldList);
    notifyListeners();

    final directDependents = fieldList
        .where((df) =>
            df.field.dependsOn == changedKey && df.field.dataSource != null)
        .toList();

    for (final df in directDependents) {
      final resolved = _resolveParams(df.field.dataSource!.params, fieldList);
      if (resolved.values.any((v) => v.toString().isEmpty)) continue;

      df.isLoadingOptions = true;
      notifyListeners();

      final generation = df.fetchGeneration;
      try {
        final options =
            await _fetchDependentOptions(df.field.dataSource!, resolved);
        if (df.fetchGeneration != generation) continue;
        df.resolvedOptions = options;
        df.optionsError = null;
      } catch (_) {
        if (df.fetchGeneration != generation) continue;
        df.optionsError = 'Failed to load options';
        df.resolvedOptions = [];
      } finally {
        if (df.fetchGeneration == generation) {
          df.isLoadingOptions = false;
          notifyListeners();
        }
      }
    }
  }

  /// Retries dependent option fetching for a subfield inside a popup form.
  Future<void> retrySubfieldOptions(
      String fieldKey, List<DynamicFieldModel> fieldList) async {
    final idx = fieldList.indexWhere((df) => df.field.key == fieldKey);
    if (idx == -1) return;
    final df = fieldList[idx];
    if (df.field.dataSource == null || df.field.dependsOn == null) return;
    await handleSubfieldDependencyChange(df.field.dependsOn!, fieldList);
  }

  Future<List<ApiOption>> _fetchDependentOptions(
    FieldDataSource ds,
    Map<String, dynamic> resolvedParams,
  ) async {
    final method = ds.method == 'POST' ? ApiMethod.post : ApiMethod.get;
    final response = await _apiClient.send<List<dynamic>>(
      ApiRequest(
        method: method,
        path: ds.endpoint,
        queryParameters: method == ApiMethod.get
            ? resolvedParams.map((k, v) => MapEntry(k, v.toString()))
            : const {},
        body: method == ApiMethod.post ? resolvedParams : null,
      ),
      decoder: (raw) => raw is List<dynamic> ? raw : null,
    );
    if (response.data == null) return [];
    return response.data!
        .whereType<Map>()
        .map((json) => ApiOption.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }
}
