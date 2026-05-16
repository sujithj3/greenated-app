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
import 'dynamic_field_form_view_model.dart';

class AddLandDetailViewModel extends DynamicFieldFormViewModel {
  AddLandDetailViewModel({
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

  bool isSaving = false;
  bool isLoadingLandForm = false;
  String? landFormError;
  String formName = '';
  int? farmerId;
  int? subcategoryId;
  List<DynamicFieldModel> fields = [];

  final Map<String, bool> _uploadingFields = {};

  int? get currentUserId => _authService.userId;

  bool isFieldVisible(DynamicFieldModel df) => shouldShowField(df, fields);

  @override
  bool isFieldUploading(String key) => _uploadingFields[key] ?? false;

  Future<LandFormData?> loadLandForm({required int subcategoryId}) async {
    isLoadingLandForm = true;
    landFormError = null;
    notifyListeners();

    try {
      final landFormData = await _service.fetchLandForm(subcategoryId);
      if (landFormData.firstUsableForm == null) {
        landFormError = 'No land form fields available.';
        return null;
      }
      return landFormData;
    } catch (e) {
      landFormError = e.toString();
      return null;
    } finally {
      isLoadingLandForm = false;
      notifyListeners();
    }
  }

  void useLandForm({
    required LandFormData landFormData,
    required int? farmerId,
  }) {
    final form = landFormData.firstUsableForm;
    this.farmerId = farmerId;
    subcategoryId = landFormData.subcategoryId;
    formName = form?.formName ?? '';
    fields = (form?.fields ?? const <ApiField>[])
        .map((field) => DynamicFieldModel.fromApiField(field))
        .toList();
    isLoadingLandForm = false;
    landFormError = null;
    isSaving = false;
    notifyListeners();
  }

  void useExistingLand({
    required LandDetail land,
    required String name,
  }) {
    farmerId = null;
    subcategoryId = null;
    formName = name;
    fields = land.fields.map((field) => field.copyWith()).toList();
    isSaving = false;
    notifyListeners();
  }

  void updateFieldValue(String key, dynamic value) {
    final idx = fields.indexWhere((df) => df.field.key == key);
    if (idx == -1) return;
    fields[idx].value = value;
    notifyListeners();
    _handleDependencyChange(key);
  }

  void applyCurrentValues(Map<String, String> textValues) {
    _applyCurrentValues(fields, textValues);
    notifyListeners();
  }

  Future<bool> submitLandRegistration({
    required Map<String, String> textValues,
  }) async {
    final landFarmerId = farmerId;
    if (landFarmerId == null || landFarmerId <= 0) {
      throw StateError('Farmer details not found. Please try again.');
    }

    applyCurrentValues(textValues);

    isSaving = true;
    notifyListeners();

    final payload = _buildSubmitPayload();
    final prettyJson = const JsonEncoder.withIndent('  ').convert(payload);
    debugPrint('=== SUBMITTING ADD LAND REGISTRATION ===');
    debugPrint(prettyJson);
    debugPrint('========================================');

    try {
      await _service.submitLandRegistration(landFarmerId, payload);
      debugPrint(
          '=== ADD LAND REGISTRATION RESULT === action=register_land success=true');
      return true;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<ImageUploadResult?> uploadCameraImage(
    String fieldKey,
    String localFilePath,
  ) async {
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

  void clearCameraImage(String fieldKey) {
    final idx = fields.indexWhere((df) => df.field.key == fieldKey);
    if (idx != -1) {
      fields[idx].value = null;
      fields[idx].previewUrl = null;
      notifyListeners();
    }
  }

  @override
  Future<ImageUploadResult?> uploadImageOnly(
    String fieldKey,
    String localFilePath,
  ) async {
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

  Future<void> retryFetchOptions(String fieldKey) async {
    final idx = fields.indexWhere((df) => df.field.key == fieldKey);
    if (idx == -1) return;
    final df = fields[idx];
    if (df.field.dataSource == null || df.field.dependsOn == null) return;
    await _handleDependencyChange(df.field.dependsOn!);
  }

  void _applyCurrentValues(
    List<DynamicFieldModel> fieldList,
    Map<String, String> textValues,
  ) {
    for (final df in fieldList) {
      if (!shouldShowField(df, fieldList)) {
        df.value = null;
        df.previewUrl = null;
        continue;
      }

      if (textValues.containsKey(df.field.key)) {
        final text = textValues[df.field.key]!.trim();
        df.value = text.isNotEmpty ? text : null;
      }

      final value = df.value;
      if (value is List<DynamicFieldModel>) {
        _applyCurrentValues(value, const {});
      }
    }
  }

  Map<String, dynamic> _buildSubmitPayload() {
    return <String, dynamic>{
      'registrationData': <String, dynamic>{
        'subcategoryId': subcategoryId,
        'registrationDate': DateTime.now().toIso8601String(),
        'status': 'Active',
        'userId': currentUserId,
        'fields': fields.map(_fieldToSubmitJson).toList(),
      },
    };
  }

  Map<String, dynamic> _fieldToSubmitJson(DynamicFieldModel field) {
    final json = field.toJson();
    _normalizeDataSourceEndpoint(json);

    if (field.value is List<DynamicFieldModel>) {
      json['options'] = json['options'] ?? <Map<String, dynamic>>[];
      json['fields'] = (field.value as List<DynamicFieldModel>)
          .map(_fieldToSubmitJson)
          .toList();
      return json;
    }

    json['value'] = _normalizeSubmitValue(field);
    return json;
  }

  dynamic _normalizeSubmitValue(DynamicFieldModel field) {
    final value = field.value;
    if (field.field.fieldStyle == FieldStyle.dropdown && value is String) {
      return int.tryParse(value) ?? value;
    }
    if (field.field.fieldStyle == FieldStyle.number && value is String) {
      return num.tryParse(value) ?? value;
    }
    if (field.field.fieldStyle == FieldStyle.mapPolygon) {
      return value ?? <Map<String, dynamic>>[];
    }
    return value;
  }

  void _normalizeDataSourceEndpoint(Map<String, dynamic> fieldJson) {
    final dataSource = fieldJson['dataSource'];
    if (dataSource is! Map) return;

    final endpoint = dataSource['endpoint']?.toString();
    if (endpoint == null || endpoint.isEmpty || endpoint.startsWith('/')) {
      return;
    }
    dataSource['endpoint'] = '/$endpoint';
  }

  Map<String, dynamic> _resolveParams(
    Map<String, String> templates, [
    List<DynamicFieldModel>? fieldList,
  ]) {
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

  @override
  Future<void> handleSubfieldDependencyChange(
    String changedKey,
    List<DynamicFieldModel> fieldList,
  ) async {
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

  @override
  Future<void> retrySubfieldOptions(
    String fieldKey,
    List<DynamicFieldModel> fieldList,
  ) async {
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
