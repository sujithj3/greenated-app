import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_method.dart';
import '../../core/network/api_request.dart';
import '../../models/api/api_models.dart';
import '../../services/auth_service.dart';
import '../../services/form_config_service.dart';
import '../../services/image_upload_service.dart'
    show ImageUploadService, ImageUploadResult;
import '../../services/registration_form_service.dart';

class FarmerFormViewModel extends ChangeNotifier {
  final FormConfigService _formConfigService;
  final RegistrationFormService _registrationService;
  final AuthService _authService;
  final ImageUploadService _imageUploadService;
  final ApiClient _apiClient;

  FarmerFormViewModel(
    this._formConfigService,
    this._registrationService,
    this._authService,
    this._imageUploadService,
    this._apiClient,
  );

  // ── State ────────────────────────────────────────────────────────────────

  String selectedCategory = '';
  String selectedSubcategory = '';
  int? selectedSubcategoryId;
  String selectedLandUnit = 'Acres';
  String selectedStatus = 'Active';
  List<Map<String, double>> landCoordinates = [];

  bool isLoadingForm = true;
  bool isSaving = false;
  String? formLoadError;

  /// Tracks per-field upload state for camera fields (key → isUploading).
  final Map<String, bool> _uploadingFields = {};

  ApiForm? form;
  List<DynamicFieldModel> dynamicFields = [];

  bool _argsProcessed = false;

  final List<String> landUnits = const [
    'Acres',
    'Hectares',
    'Bigha',
    'Sq. Meters',
  ];

  // ── Derived getters ──────────────────────────────────────────────────────

  bool get geoRequired => form?.geoLocationRequired ?? false;

  // ── Init ─────────────────────────────────────────────────────────────────

  void initFromArgs(Map? args) {
    if (_argsProcessed) return;
    _argsProcessed = true;

    if (args != null) {
      selectedCategory = args['category'] as String? ?? '';
      selectedSubcategory = args['subcategory'] as String? ?? '';
      selectedSubcategoryId = args['subcategoryId'] as int?;
    }
  }

  Future<void> loadForm() async {
    isLoadingForm = true;
    formLoadError = null;
    notifyListeners();

    try {
      selectedSubcategoryId ??= _formConfigService
          .getCategoryByName(selectedCategory)
          ?.findSubcategory(selectedSubcategory)
          ?.subcategoryId;

      if (selectedSubcategoryId != null) {
        form = await _formConfigService
            .getDynamicRegistrationFields(selectedSubcategoryId!);
      } else {
        form = null;
      }
    } catch (error) {
      form = null;
      formLoadError = error.toString();
    }

    _initDynamicFields();

    isLoadingForm = false;
    notifyListeners();
  }

  void _initDynamicFields() {
    dynamicFields.clear();
    if (form == null) return;
    for (final field in form!.fields) {
      dynamicFields.add(DynamicFieldModel.fromApiField(field));
    }
  }

  /// Returns the initial text value for a dynamic field key (for View to seed
  /// TextEditingControllers after form loads).
  String initialTextFor(String key) {
    final idx = dynamicFields.indexWhere((df) => df.field.key == key);
    if (idx == -1) return '';
    final v = dynamicFields[idx].value;
    return v?.toString() ?? '';
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  void setLandUnit(String unit) {
    selectedLandUnit = unit;
    notifyListeners();
  }

  void setLandResult(Map<String, dynamic> result) {
    final area = result['area'] as double? ?? 0;
    final coords = result['coordinates'] as List<Map<String, double>>? ?? [];
    landCoordinates = coords;
    if (area > 0) selectedLandUnit = 'Acres';
    notifyListeners();
  }

  void updateDynamicFieldValue(String key, dynamic value) {
    final idx = dynamicFields.indexWhere((df) => df.field.key == key);
    if (idx != -1) {
      dynamicFields[idx].value = value;
      notifyListeners();
      _handleDependencyChange(key); // fire-and-forget
    }
  }

  /// Whether a field should be visible based on its showWhen condition.
  bool isFieldVisible(DynamicFieldModel df) =>
      shouldShowField(df, dynamicFields);

  /// Whether a specific camera field is currently uploading.
  bool isFieldUploading(String key) => _uploadingFields[key] ?? false;

  /// Uploads a captured image for a camera-type dynamic field.
  ///
  /// [fieldKey] identifies which dynamic field to store the imagePath in.
  /// [localFilePath] is the path returned from the camera capture screen.
  ///
  /// Returns the [ImageUploadResult] on success, or null on failure.
  Future<ImageUploadResult?> uploadCameraImage(
      String fieldKey, String localFilePath) async {
    _uploadingFields[fieldKey] = true;
    notifyListeners();

    try {
      final result = await _imageUploadService.uploadImage(localFilePath);
      final idx = dynamicFields.indexWhere((df) => df.field.key == fieldKey);
      if (idx != -1) {
        dynamicFields[idx].value = result.imagePath;
        dynamicFields[idx].previewUrl = result.previewUrl;
        notifyListeners();
        _handleDependencyChange(fieldKey);
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
    final idx = dynamicFields.indexWhere((df) => df.field.key == fieldKey);
    if (idx != -1) {
      dynamicFields[idx].value = null;
      dynamicFields[idx].previewUrl = null;
      notifyListeners();
    }
  }

  /// Saves the registration. [textControllers] is a map of key → current text
  /// for text/number/date fields, passed from the View.
  /// Returns true on success, false on validation failure, throws on API error.
  Future<bool> save({
    required Map<String, String> textValues,
    required String landAreaText,
  }) async {
    if (selectedCategory.isEmpty || selectedSubcategory.isEmpty) return false;

    // Apply text values from controllers into dynamicFields; null out hidden fields
    for (final df in dynamicFields) {
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

    final Map<String, dynamic> allDynValues = {};
    for (final df in dynamicFields) {
      final k = df.field.key;
      final v = df.value;
      if (v == null) continue;

      if (df.field.isPopupForm && v is List<DynamicFieldModel>) {
        final asMap = <String, dynamic>{};
        for (final subDf in v) {
          if (subDf.value != null && subDf.value != '') {
            asMap[subDf.field.key] = subDf.value;
          }
        }
        if (asMap.isNotEmpty) allDynValues[k] = asMap;
      } else if (v is Map && v.isNotEmpty) {
        allDynValues[k] = v;
      } else if (v is String && v.isNotEmpty) {
        allDynValues[k] = v;
      } else if (v is bool || v is num) {
        allDynValues[k] = v;
      } else if (v is List && v.isNotEmpty) {
        allDynValues[k] = v;
      }
    }

    final List<dynamic> serializedFields =
        dynamicFields.map((e) => e.toJson()).toList();

    final submissionPayload = <String, dynamic>{
      'registrationData': <String, dynamic>{
        'subcategoryId': selectedSubcategoryId ?? 0,
        'registrationDate': DateTime.now().toIso8601String(),
        'status': selectedStatus,
        'userId': _authService.userId,
        'fields': serializedFields,
      },
    };

    final prettyJson =
        const JsonEncoder.withIndent('  ').convert(submissionPayload);
    debugPrint('=== SUBMITTING FARMER REGISTRATION ===');
    debugPrint(prettyJson);
    debugPrint('======================================');

    try {
      await _registrationService.submitRegistration(submissionPayload);
      debugPrint(
          '=== FARMER REGISTRATION RESULT === action=create_farmer success=true');
      return true;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  // ── Dependency handling ───────────────────────────────────────────────────

  Map<String, dynamic> _resolveParams(Map<String, String> templates) {
    final resolved = <String, dynamic>{};
    for (final entry in templates.entries) {
      final template = entry.value;
      String val = '';
      if (template.startsWith(r'$')) {
        final ref = template.substring(1);
        final dotIdx = ref.indexOf('.');
        final fieldKey = dotIdx > 0 ? ref.substring(0, dotIdx) : ref;
        final idx = dynamicFields.indexWhere((df) => df.field.key == fieldKey);
        val = idx != -1 ? (dynamicFields[idx].value?.toString() ?? '') : '';
      } else {
        val = template;
      }

      final parsedInt = int.tryParse(val);
      resolved[entry.key] = parsedInt ?? val;
    }
    return resolved;
  }

  void _resetDependents(String parentKey) {
    for (final df in dynamicFields) {
      if (df.field.dependsOn == parentKey) {
        df.value = null;
        df.previewUrl = null;
        df.resolvedOptions = df.field.options;
        df.isLoadingOptions = false;
        df.optionsError = null;
        df.incrementFetchGeneration();
        _resetDependents(df.field.key);
      }
    }
  }

  Future<void> _handleDependencyChange(String changedKey) async {
    _resetDependents(changedKey);
    notifyListeners();

    final directDependents = dynamicFields
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

  Future<void> retryFetchOptions(String fieldKey) async {
    final idx = dynamicFields.indexWhere((df) => df.field.key == fieldKey);
    if (idx == -1) return;
    final df = dynamicFields[idx];
    if (df.field.dataSource == null || df.field.dependsOn == null) return;
    await _handleDependencyChange(df.field.dependsOn!);
  }

  Future<void> ensureCategoriesLoaded() async {
    await _formConfigService.fetchCategories();
  }
}
