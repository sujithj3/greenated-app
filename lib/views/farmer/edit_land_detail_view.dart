import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../models/api/api_models.dart';
import '../../services/auth_service.dart';
import '../../services/file_upload_service.dart';
import '../../services/image_upload_service.dart';
import '../../services/registration_form_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/field_fill_state.dart';
import '../../utils/file_upload_helper.dart';
import '../../utils/form_validator.dart';
import '../../utils/snack_bar_helper.dart';
import '../../view_models/farmer/add_land_detail_view_model.dart';
import '../../widgets/dynamic_field_builder.dart';
import '../../widgets/land_details_widgets.dart';
import 'edit_farmer_details_view.dart';

class EditLandDetailView extends StatefulWidget {
  const EditLandDetailView({
    super.key,
    required this.land,
    required this.title,
    required this.subcategoryId,
    required this.submissionId,
  });

  final LandDetail land;
  final String title;
  final int? subcategoryId;
  final int? submissionId;

  @override
  State<EditLandDetailView> createState() => _EditLandDetailViewState();
}

class _EditLandDetailViewState extends State<EditLandDetailView> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _textCtrl = {};
  late final AddLandDetailViewModel _vm;
  bool _isInit = false;
  bool _shouldRefreshOnPop = false;
  final AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    _vm = AddLandDetailViewModel(
      service: context.read<RegistrationFormService>(),
      authService: context.read<AuthService>(),
      apiClient: context.read<ApiClient>(),
      imageUploadService: context.read<ImageUploadService>(),
      fileUploadService: context.read<FileUploadService>(),
    );
    _vm.addListener(_onVmChanged);
    _vm.useExistingLand(
      land: widget.land,
      name: widget.title,
      subcategoryId: widget.subcategoryId,
      submissionId: widget.submissionId,
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
      context.showSnack(
        _vm.lastUploadErrorMessage ?? 'Photo upload failed. Please try again.',
      );
    }
  }

  Future<void> _pickAndUploadFiles(DynamicFieldModel df) async {
    final localPaths = await pickDynamicUploadFiles(context);
    if (localPaths.isEmpty || !mounted) return;

    final result = await _vm.uploadFilesForField(df.field.key, localPaths);
    if (!mounted) return;

    if (result == null) {
      context.showSnack(
        _vm.lastUploadErrorMessage ?? 'File upload failed. Please try again.',
      );
    } else if (result.hasIncompleteData) {
      context.showSnack('Files uploaded, but some previews are unavailable.',
          success: true);
    } else {
      context.showSnack('Files uploaded successfully', success: true);
    }
  }

  Future<void> _deleteFile(DynamicFieldModel df, AppFileItem file) async {
    await _vm.deleteFileForField(df, file);
    if (!mounted) return;
    _markShouldRefreshOnPop();
  }

  void _markShouldRefreshOnPop() {
    if (_shouldRefreshOnPop || !mounted) return;
    setState(() => _shouldRefreshOnPop = true);
  }

  void _popWithRefreshResult() {
    if (!mounted) return;
    setState(() => _shouldRefreshOnPop = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.pop(context, true);
      }
    });
  }

  Future<void> _openEditPopupSheet(DynamicFieldModel df) async {
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
        onFileDeleted: _markShouldRefreshOnPop,
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
      debugPrint('=== MAP RESULT (Land Field: ${df.field.key}) ===');
      debugPrint('Raw result: $result');
      debugPrint('Cleaned coordinates (to be saved in value): $coordinates');
      _vm.updateFieldValue(df.field.key, coordinates);
    }
  }

  Future<void> _onUpdateLandDetail() async {
    final submissionId = widget.submissionId;
    final subcategoryId = widget.subcategoryId;
    final userId = _vm.currentUserId;
    if (submissionId == null ||
        submissionId <= 0 ||
        subcategoryId == null ||
        subcategoryId <= 0 ||
        userId == null ||
        userId <= 0) {
      context.showSnack('Required details not found. Please try again.');
      return;
    }

    if (_vm.isSaving) return;

    final isFormValid = _formKey.currentState?.validate() ?? true;
    final textValues = Map.fromEntries(
      _textCtrl.entries.map((entry) => MapEntry(entry.key, entry.value.text)),
    );

    _vm.applyCurrentValues(textValues);

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

    try {
      final success = await _vm.submitLandEdit(textValues: textValues);
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

  String _cleanErrorMessage(Object error) {
    final text = error.toString().trim();
    if (text.isEmpty) return '';
    return text
        .replaceFirst(RegExp(r'^ApiException:\s*'), '')
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .replaceFirst(RegExp(r'^Bad state:\s*'), '')
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

        return PopScope<Object?>(
          canPop: !_shouldRefreshOnPop,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            _popWithRefreshResult();
          },
          child: Stack(
            children: [
              Scaffold(
                appBar: AppBar(title: Text(widget.title)),
                body: _buildBody(isBlocked),
              ),
              if (isBlocked)
                AbsorbPointer(
                  absorbing: true,
                  child: showOverlay
                      ? Container(
                          color: Colors.black.withValues(alpha: 0.45),
                          child: const Center(
                            child:
                                CircularProgressIndicator(color: Colors.white),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
            ],
          ),
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
          'No data available',
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
            label: 'Update Land Detail',
            icon: Icons.cloud_upload_outlined,
            onPressed: isBlocked ? null : _onUpdateLandDetail,
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

    final isCameraField = f.fieldStyle == FieldStyle.camera;
    final isFileField = f.fieldStyle == FieldStyle.file;

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
      onPopupFormPressed: f.isPopupForm ? () => _openEditPopupSheet(df) : null,
      popupFormFilledCount: popupFormFilled,
      popupFormTotalCount: popupFormTotal,
      isUploading:
          (isCameraField || isFileField) ? _vm.isFieldUploading(f.key) : false,
      onCapturePhoto: isCameraField ? () => _captureAndUpload(f.key) : null,
      onClearPhoto: isCameraField ? () => _vm.clearCameraImage(f.key) : null,
      onAddFiles: isFileField ? () => _pickAndUploadFiles(df) : null,
      onDeleteFile: isFileField ? (file) => _deleteFile(df, file) : null,
      previewUrl: (isCameraField || isFileField) ? df.previewUrl : null,
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
