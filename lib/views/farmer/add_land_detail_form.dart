import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../models/api/api_models.dart';
import '../../services/auth_service.dart';
import '../../services/image_upload_service.dart';
import '../../services/registration_form_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/field_fill_state.dart';
import '../../utils/form_validator.dart';
import '../../utils/snack_bar_helper.dart';
import '../../view_models/farmer/edit_farmer_details_view_model.dart';
import '../../widgets/dynamic_field_builder.dart';
import '../../widgets/land_details_widgets.dart';
import 'edit_farmer_details_view.dart';

class AddLandDetailForm extends StatefulWidget {
  const AddLandDetailForm({
    super.key,
    required this.landFormData,
    required this.farmerId,
  });

  final LandFormData landFormData;
  final int? farmerId;

  @override
  State<AddLandDetailForm> createState() => _AddLandDetailFormState();
}

class _AddLandDetailFormState extends State<AddLandDetailForm> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _textCtrl = {};
  late final EditFarmerDetailsViewModel _vm;
  bool _isInit = false;
  final AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;

  ApiForm? get _form => widget.landFormData.firstUsableForm;

  @override
  void initState() {
    super.initState();
    _vm = EditFarmerDetailsViewModel(
      service: context.read<RegistrationFormService>(),
      authService: context.read<AuthService>(),
      apiClient: context.read<ApiClient>(),
      imageUploadService: context.read<ImageUploadService>(),
    );
    _vm.addListener(_onVmChanged);
    final form = _form;
    _vm.useLocalFields(
      (form?.fields ?? const <ApiField>[])
          .map((field) => DynamicFieldModel.fromApiField(field))
          .toList(),
      name: form?.formName,
    );
  }

  @override
  void dispose() {
    _vm.removeListener(_onVmChanged);
    for (final controller in _textCtrl.values) {
      controller.dispose();
    }
    _vm.dispose();
    super.dispose();
  }

  void _onVmChanged() {
    if (!mounted) return;
    _syncTextControllers();
    setState(() {});
  }

  void _syncTextControllers() {
    final currentKeys = _vm.fields.map((df) => df.field.key).toSet();
    _textCtrl.removeWhere((key, ctrl) {
      if (!currentKeys.contains(key)) {
        ctrl.dispose();
        return true;
      }
      return false;
    });

    for (final df in _vm.fields) {
      final f = df.field;
      if (f.fieldStyle == FieldStyle.text ||
          f.fieldStyle == FieldStyle.number ||
          f.fieldStyle == FieldStyle.date) {
        var initial = df.value?.toString() ?? '';
        if (f.fieldStyle == FieldStyle.date && initial.isNotEmpty) {
          initial = formatDateForDisplay(initial);
        }
        if (!_textCtrl.containsKey(f.key)) {
          _textCtrl[f.key] = TextEditingController(text: initial);
        } else if (_textCtrl[f.key]!.text != initial && !_isInit) {
          _textCtrl[f.key]!.text = initial;
        }
      }
    }
    _isInit = true;

    for (final df in _vm.fields) {
      if (!_vm.isFieldVisible(df) && _textCtrl.containsKey(df.field.key)) {
        _textCtrl[df.field.key]!.clear();
      }
    }
  }

  Future<void> _captureAndUpload(String fieldKey) async {
    final localPath =
        await Navigator.pushNamed(context, '/camera-capture') as String?;
    if (localPath == null || !mounted) return;

    final result = await _vm.uploadCameraImage(fieldKey, localPath);
    if (!mounted) return;

    if (result != null) {
      context.showSnack('Photo uploaded successfully', success: true);
    } else {
      context.showSnack('Photo upload failed. Please try again.');
    }
  }

  Future<void> _openPopupSheet(DynamicFieldModel df) async {
    final currentValues = df.value as List<DynamicFieldModel>? ?? [];
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditPopupFormSheet(
        parentField: df.field,
        initialFields: currentValues,
        onSaved: (result) {
          _vm.updateFieldValue(df.field.key, result);
          df.clearError();
          if (mounted) setState(() {});
        },
        viewModel: _vm,
      ),
    );
  }

  Future<void> _openMapForField(DynamicFieldModel df) async {
    final result = await Navigator.pushNamed(
      context,
      '/land-measurement',
      arguments: {
        'initialPolygon': df.value,
        'viewOnly': false,
      },
    );

    if (result != null && result is Map) {
      final coordinates = result['coordinates'] as List<dynamic>? ?? [];
      debugPrint('=== MAP RESULT (Add Land Field: ${df.field.key}) ===');
      debugPrint('Raw result: $result');
      debugPrint('Cleaned coordinates (to be saved in value): $coordinates');
      _vm.updateFieldValue(df.field.key, coordinates);
    }
  }

  Future<void> _onSubmit() async {
    final farmerId = widget.farmerId;
    if (farmerId == null || farmerId <= 0) {
      context.showSnack('Farmer details not found. Please try again.');
      return;
    }

    if (_vm.isSaving) return;

    final isFormValid = _formKey.currentState?.validate() ?? true;
    final textValues = Map.fromEntries(
      _textCtrl.entries.map((e) => MapEntry(e.key, e.value.text)),
    );

    _applyCurrentValues(_vm.fields, textValues);

    final visibleFields =
        _vm.fields.where((df) => _vm.isFieldVisible(df)).toList();
    final validationResult = validateFields(
      visibleFields,
      textValues: textValues,
    );

    if (!validationResult.isValid) {
      if (mounted) {
        setState(() {});
        context.showSnack(
          'Please fill the required field: ${validationResult.firstInvalidLabel}',
        );
      }
      return;
    }

    if (!isFormValid) {
      if (mounted) context.showSnack('Please fix the errors in the form.');
      return;
    }

    Map<String, dynamic> payload;
    try {
      payload = _buildSubmitPayload();
    } catch (_) {
      if (mounted) context.showSnack('Something went wrong. Please try again.');
      return;
    }

    try {
      final success = await _vm.submitLandRegistration(
        farmerId: farmerId,
        payload: payload,
      );
      if (success && mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        final message = _cleanErrorMessage(e);
        context.showSnack(
          message.isEmpty ? 'Something went wrong. Please try again.' : message,
        );
      }
    }
  }

  void _applyCurrentValues(
    List<DynamicFieldModel> fields,
    Map<String, String> textValues,
  ) {
    for (final df in fields) {
      if (!shouldShowField(df, fields)) {
        df.value = null;
        df.previewUrl = null;
        _textCtrl[df.field.key]?.clear();
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
        'subcategoryId': widget.landFormData.subcategoryId,
        'registrationDate': DateTime.now().toIso8601String(),
        'status': 'Active',
        'userId': _vm.currentUserId,
        'fields': _vm.fields.map(_fieldToSubmitJson).toList(),
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

  String _cleanErrorMessage(Object error) {
    final text = error.toString().trim();
    if (text.isEmpty) return '';
    return text
        .replaceFirst(RegExp(r'^ApiException:\s*'), '')
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        final isUploading =
            _vm.fields.any((df) => _vm.isFieldUploading(df.field.key));
        final showOverlay =
            _vm.isSaving || _vm.fields.any((df) => df.isLoadingOptions);
        final isBlocked = showOverlay || isUploading;

        return Stack(
          children: [
            Scaffold(
              appBar: AppBar(
                title: const Text('Add Land Detail'),
                centerTitle: false,
              ),
              body: _buildBody(isBlocked),
            ),
            if (isBlocked)
              AbsorbPointer(
                absorbing: true,
                child: showOverlay
                    ? Container(
                        color: Colors.black.withValues(alpha: 0.45),
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
          ],
        );
      },
    );
  }

  Widget _buildBody(bool isBlocked) {
    final visibleFields =
        _vm.fields.where((df) => _vm.isFieldVisible(df)).toList();

    if (visibleFields.isEmpty) {
      return const Center(
        child: Text(
          'No land form fields available',
          style: TextStyle(color: AppColors.textMedium, fontSize: 16),
        ),
      );
    }

    return Form(
      key: _formKey,
      autovalidateMode: _autoValidateMode,
      child: Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: visibleFields.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, index) => _buildField(visibleFields[index]),
            ),
          ),
          BottomUpdateButton(
            label: 'Submit',
            icon: Icons.check_circle_outline,
            onPressed: isBlocked ? null : _onSubmit,
          ),
        ],
      ),
    );
  }

  Widget _buildField(DynamicFieldModel df) {
    final f = df.field;

    int? popupFormFilled;
    int? popupFormTotal;
    if (f.isPopupForm) {
      final subFields = df.value as List<DynamicFieldModel>? ?? [];
      popupFormTotal = getTotalCount(subFields);
      popupFormFilled = getFilledCount(subFields);
    }

    final isCameraField = f.fieldStyle == FieldStyle.camera ||
        f.fieldStyle == FieldStyle.cameraFile;

    return DynamicFieldBuilder(
      field: f,
      value: _textCtrl.containsKey(f.key) ? _textCtrl[f.key]!.text : df.value,
      textController: _textCtrl[f.key],
      accentColor: AppColors.primary,
      hasError: df.hasError,
      errorMessage: df.errorMessage,
      onChanged: (val) {
        _vm.updateFieldValue(f.key, val);
      },
      onPopupFormPressed: f.isPopupForm ? () => _openPopupSheet(df) : null,
      popupFormFilledCount: popupFormFilled,
      popupFormTotalCount: popupFormTotal,
      isUploading: isCameraField ? _vm.isFieldUploading(f.key) : false,
      onCapturePhoto: isCameraField ? () => _captureAndUpload(f.key) : null,
      onClearPhoto: isCameraField ? () => _vm.clearCameraImage(f.key) : null,
      previewUrl: isCameraField ? df.previewUrl : null,
      onMapPolygonPressed: f.fieldStyle == FieldStyle.mapPolygon
          ? () => _openMapForField(df)
          : null,
      resolvedOptions:
          f.fieldStyle == FieldStyle.dropdown ? df.resolvedOptions : null,
      isLoadingOptions:
          f.fieldStyle == FieldStyle.dropdown ? df.isLoadingOptions : false,
      optionsError:
          f.fieldStyle == FieldStyle.dropdown ? df.optionsError : null,
      onRetryOptions:
          f.fieldStyle == FieldStyle.dropdown && df.optionsError != null
              ? () => _vm.retryFetchOptions(f.key)
              : null,
    );
  }
}
