import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../models/api/api_models.dart';
import '../../models/farmer/farmer_model.dart';
import '../../services/auth_service.dart';
import '../../services/form_config_service.dart';
import '../../services/image_upload_service.dart';
import '../../services/registration_form_service.dart';

class FarmerFormViewModel extends ChangeNotifier {
  final FormConfigService _formConfigService;
  final RegistrationFormService _registrationService;
  final AuthService _authService;
  final ImageUploadService _imageUploadService;

  FarmerFormViewModel(
    this._formConfigService,
    this._registrationService,
    this._authService,
    this._imageUploadService,
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
  FarmerModel? editFarmer;

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

      if (args['farmer'] != null) {
        editFarmer = args['farmer'] as FarmerModel;
        if (selectedCategory.isEmpty) selectedCategory = editFarmer!.category;
        if (selectedSubcategory.isEmpty) {
          selectedSubcategory = editFarmer!.subcategory;
        }
        selectedSubcategoryId ??= editFarmer!.subcategoryId;
      }
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

    if (editFarmer != null) {
      _populateFromFarmer(editFarmer!);
    }

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

  void _populateFromFarmer(FarmerModel f) {
    selectedCategory = f.category;
    selectedSubcategory = f.subcategory;
    selectedSubcategoryId = f.subcategoryId;
    selectedLandUnit = f.landUnit;
    selectedStatus = f.status;
    landCoordinates = f.landCoordinates;

    if (f.formFields.isNotEmpty) {
      dynamicFields = f.formFields
          .map((e) =>
              DynamicFieldModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } else {
      if (f.name != null) _setDynValue('fullName', f.name!);
      if (f.phone != null) _setDynValue('mobileNumber', f.phone!);
      f.dynamicFields.forEach((key, value) => _setDynValue(key, value));
    }
  }

  void _setDynValue(String key, dynamic value) {
    if (value == null) return;
    if (value is String && value.isEmpty) return;
    final idx = dynamicFields.indexWhere((df) => df.field.key == key);
    if (idx != -1) dynamicFields[idx].value = value;
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
    }
  }

  /// Whether a specific camera field is currently uploading.
  bool isFieldUploading(String key) => _uploadingFields[key] ?? false;

  /// Uploads a captured image for a camera-type dynamic field.
  ///
  /// [fieldKey] identifies which dynamic field to store the URL in.
  /// [localFilePath] is the path returned from the camera capture screen.
  ///
  /// Returns the uploaded image URL on success, or null on failure.
  Future<String?> uploadCameraImage(String fieldKey, String localFilePath) async {
    _uploadingFields[fieldKey] = true;
    notifyListeners();

    try {
      final url = await _imageUploadService.uploadImage(localFilePath);
      updateDynamicFieldValue(fieldKey, url);
      return url;
    } catch (e) {
      debugPrint('Image upload failed for field "$fieldKey": $e');
      return null;
    } finally {
      _uploadingFields[fieldKey] = false;
      notifyListeners();
    }
  }

  /// Clears the uploaded image URL for a camera-type dynamic field.
  void clearCameraImage(String fieldKey) {
    updateDynamicFieldValue(fieldKey, null);
  }

  /// Saves the registration. [textControllers] is a map of key → current text
  /// for text/number/date fields, passed from the View.
  /// Returns true on success, false on validation failure, throws on API error.
  Future<bool> save({
    required Map<String, String> textValues,
    required String landAreaText,
  }) async {
    if (selectedCategory.isEmpty || selectedSubcategory.isEmpty) return false;
    if (editFarmer != null) return false; // edit not yet supported

    // Apply text values from controllers into dynamicFields
    for (final df in dynamicFields) {
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

  Future<void> ensureCategoriesLoaded() async {
    await _formConfigService.fetchCategories();
  }
}
