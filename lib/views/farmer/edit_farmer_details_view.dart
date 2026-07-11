// Edit farmer details view — edits a previously submitted farmer registration.
//
// Fetches prefilled form data via the `form-edit` GET endpoint and renders an
// editable dynamic form. Maintains fully independent state from the create and
// detail flows.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../models/api/api_models.dart';
import '../../utils/field_fill_state.dart';
import '../../services/auth_service.dart';
import '../../services/file_upload_service.dart';
import '../../services/image_upload_service.dart';
import '../../services/registration_form_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/file_upload_helper.dart';
import '../../utils/form_validator.dart';
import '../../utils/repeatable_popup_form_utils.dart';
import '../../utils/snack_bar_helper.dart';
import '../../view_models/farmer/add_land_detail_view_model.dart';
import '../../view_models/farmer/dynamic_field_form_view_model.dart';
import '../../view_models/farmer/edit_farmer_details_view_model.dart';
import '../../widgets/dynamic_field_builder.dart';
import '../../widgets/land_details_widgets.dart';
import '../../widgets/popup_form.dart';
import '../../widgets/shimmer_loading.dart';

class EditFarmerDetailsView extends StatefulWidget {
  final int subcategoryId;
  final int farmerId;

  const EditFarmerDetailsView({
    super.key,
    required this.subcategoryId,
    required this.farmerId,
  });

  @override
  State<EditFarmerDetailsView> createState() => _EditFarmerDetailsViewState();
}

class _EditFarmerDetailsViewState extends State<EditFarmerDetailsView> {
  final _formKey = GlobalKey<FormState>();
  late final EditFarmerDetailsViewModel _vm;
  late final AddLandDetailViewModel _landVm;
  final Map<String, TextEditingController> _textCtrl = {};
  bool _isInit = false;
  bool _shouldRefreshOnPop = false;
  final AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    _vm = EditFarmerDetailsViewModel(
      service: context.read<RegistrationFormService>(),
      authService: context.read<AuthService>(),
      apiClient: context.read<ApiClient>(),
      imageUploadService: context.read<ImageUploadService>(),
      fileUploadService: context.read<FileUploadService>(),
    );
    _landVm = AddLandDetailViewModel(
      service: context.read<RegistrationFormService>(),
      authService: context.read<AuthService>(),
      apiClient: context.read<ApiClient>(),
      imageUploadService: context.read<ImageUploadService>(),
      fileUploadService: context.read<FileUploadService>(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) return;
    _isInit = true;

    _vm.addListener(_onVmChanged);
    _landVm.addListener(_onVmChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        await _vm.loadEditForm(
          subcategoryId: widget.subcategoryId,
          farmerId: widget.farmerId,
        );
      }
    });
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
        } else if (initial.isNotEmpty && _textCtrl[f.key]!.text.isEmpty) {
          _textCtrl[f.key]!.text = initial;
        }
      }
    }

    // Clear text controllers for fields that are now hidden
    for (final df in _vm.fields) {
      if (!_vm.isFieldVisible(df) && _textCtrl.containsKey(df.field.key)) {
        _textCtrl[df.field.key]!.clear();
      }
    }
  }

  @override
  void dispose() {
    _vm.removeListener(_onVmChanged);
    _landVm.removeListener(_onVmChanged);
    for (final c in _textCtrl.values) {
      c.dispose();
    }
    _vm.dispose();
    _landVm.dispose();
    super.dispose();
  }

  // ── Camera capture + upload ─────────────────────────────────────────────

  Future<void> _captureAndUpload(String fieldKey) async {
    final localPath = await Navigator.pushNamed(
      context,
      '/camera-capture',
      arguments: const {'requiresLocation': true},
    ) as String?;
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
    final localPaths = await pickDynamicUploadFiles(
      context,
      requiresLocationForCamera: true,
    );
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

  Future<void> _reloadEditFormAfterDelete() async {
    _markShouldRefreshOnPop();
    await _vm.loadEditForm(
      subcategoryId: widget.subcategoryId,
      farmerId: widget.farmerId,
    );
  }

  Future<void> _deleteCameraPhoto(DynamicFieldModel df) async {
    final confirmed = await showPopupConfirm(
      context,
      title: 'Remove photo?',
      message: 'Remove this photo? This action cannot be undone.',
      confirmLabel: 'Remove',
      confirmColor: AppColors.error,
      icon: Icons.delete_outline,
    );
    if (confirmed != true || !mounted) return;

    final path = df.value?.toString().trim() ?? '';
    try {
      await _vm.deleteFileOnly(
        df.field.key,
        path,
        fieldId: df.field.fieldId,
        submissionId: _vm.editSubmissionId,
      );
      if (!mounted) return;

      _vm.clearCameraImage(df.field.key);
      await _reloadEditFormAfterDelete();
      if (!mounted) return;
      context.showSnack('Photo removed successfully', success: true);
    } catch (_) {
      if (mounted) {
        context.showSnack('Unable to remove photo. Please try again.');
      }
    }
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

  // ── Popup Form Sheet (view + edit) ──────────────────────────────────────

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
          // Clear parent error after popup is saved
          df.clearError();
          if (mounted) setState(() {});
        },
        onRepeatableSubmitRequested: () => _submitUpdate(popOnSuccess: false),
        onFileDeleted: _markShouldRefreshOnPop,
        onCameraPhotoDeleted: _reloadEditFormAfterDelete,
        viewModel: _vm,
        isEditMode: true,
      ),
    );
  }

  // ── Map Polygon ─────────────────────────────────────────────────────────

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
      debugPrint('=== MAP RESULT (Main Field: ${df.field.key}) ===');
      debugPrint('Raw result: $result');
      debugPrint('Cleaned coordinates (to be saved in value): $coordinates');
      _vm.updateFieldValue(df.field.key, coordinates);
    }
  }

  Future<void> _openAddLandDetailForm() async {
    final landFormData =
        await _landVm.loadLandForm(subcategoryId: widget.subcategoryId);
    if (!mounted) return;

    if (landFormData == null) {
      context.showSnack(
        _landVm.landFormError ?? 'Unable to load land form. Please try again.',
      );
      return;
    }

    final result = await Navigator.pushNamed(
      context,
      '/add-land-detail',
      arguments: {
        'farmerId': widget.farmerId,
        'landFormData': landFormData,
      },
    );

    if (result == true && mounted) {
      _markShouldRefreshOnPop();
      await _vm.loadEditForm(
        subcategoryId: widget.subcategoryId,
        farmerId: widget.farmerId,
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        final isUploading =
            _vm.fields.any((df) => _vm.isFieldUploading(df.field.key));
        final showOverlay = _vm.isSaving ||
            _landVm.isLoadingLandForm ||
            _vm.fields.any((df) => df.isLoadingOptions);
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
                appBar: AppBar(
                  title: Text(_vm.formName.isNotEmpty
                      ? 'Edit ${_vm.formName}'
                      : 'Edit'),
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
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(color: Colors.white),
                              ],
                            ),
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
    if (_vm.isLoading) {
      return const ShimmerFormSkeleton();
    }

    if (_vm.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined,
                  size: 40, color: AppColors.textMedium),
              const SizedBox(height: 12),
              const Text(
                'Unable to load edit form',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dark),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(_vm.error!,
                  style: const TextStyle(color: AppColors.textMedium),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _vm.loadEditForm(
                  subcategoryId: widget.subcategoryId,
                  farmerId: widget.farmerId,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_vm.fields.isEmpty && _vm.landDetails.isEmpty) {
      return const Center(
        child: Text('No data available',
            style: TextStyle(color: AppColors.textMedium, fontSize: 16)),
      );
    }

    final visibleFields =
        _vm.fields.where((df) => _vm.isFieldVisible(df)).toList();

    return Form(
      key: _formKey,
      autovalidateMode: _autoValidateMode,
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
                  children: [
                    ...visibleFields.map(
                      (field) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildField(field),
                      ),
                    ),
                    const SizedBox(height: 16),
                    LandDetailsSection(
                      lands: _vm.landDetails,
                      onLandTap: (land, _, title) async {
                        final result = await Navigator.pushNamed(
                          context,
                          '/edit-land-detail',
                          arguments: {
                            'land': land,
                            'title': title,
                            'subcategoryId': widget.subcategoryId,
                            'submissionId': land.submissionId,
                          },
                        );
                        if (result == true && mounted) {
                          _markShouldRefreshOnPop();
                          await _vm.loadEditForm(
                            subcategoryId: widget.subcategoryId,
                            farmerId: widget.farmerId,
                          );
                        }
                      },
                    ),
                  ],
                ),
                Positioned(
                  right: 16,
                  bottom: 24,
                  child: AddNewLandButton(
                    onPressed:
                        isBlocked ? () {} : () => _openAddLandDetailForm(),
                  ),
                ),
              ],
            ),
          ),
          _buildSubmitButton(isBlocked),
        ],
      ),
    );
  }

  Widget _buildField(DynamicFieldModel df) {
    final f = df.field;

    int? popupFormFilled;
    int? popupFormTotal;
    if (f.isFormContainer) {
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
      onPopupFormPressed:
          f.isFormContainer ? () => _openEditPopupSheet(df) : null,
      popupFormFilledCount: popupFormFilled,
      popupFormTotalCount: popupFormTotal,
      // Camera field wiring
      isUploading:
          (isCameraField || isFileField) ? _vm.isFieldUploading(f.key) : false,
      onCapturePhoto: isCameraField ? () => _captureAndUpload(f.key) : null,
      onClearPhoto: isCameraField ? () => _vm.clearCameraImage(f.key) : null,
      onDeleteCameraPhoto: isCameraField ? () => _deleteCameraPhoto(df) : null,
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

  Future<void> _save() async {
    await _submitUpdate();
  }

  Future<bool> _submitUpdate({bool popOnSuccess = true}) async {
    if (_vm.isSaving) return false;

    final isFormValid = _formKey.currentState?.validate() ?? true;

    final textValues = Map.fromEntries(
      _textCtrl.entries.map((e) => MapEntry(e.key, e.value.text)),
    );

    final visibleFields =
        _vm.fields.where((df) => _vm.isFieldVisible(df)).toList();
    final validationResult = validateFields(
      visibleFields,
      textValues: textValues,
    );

    if (!validationResult.isValid) {
      if (mounted) {
        context.showSnack(
          'Please fill the required field: ${validationResult.firstInvalidLabel}',
        );
      }
      return false;
    }

    if (!isFormValid) {
      if (mounted) {
        context.showSnack('Please fix the errors in the form.');
      }
      return false;
    }

    try {
      final success = await _vm.save(
        textValues: textValues,
        subcategoryId: widget.subcategoryId,
        farmerId: widget.farmerId,
      );
      if (success && mounted) {
        context.showSnack('Farmer details updated!', success: true);
        if (popOnSuccess) {
          Navigator.pop(context, true);
        } else {
          _markShouldRefreshOnPop();
        }
      }
      return success;
    } catch (e) {
      if (mounted) context.showSnack('Error: ${e.toString()}');
      return false;
    }
  }

  Widget _buildSubmitButton(bool isBlocked) {
    return BottomUpdateButton(
      label: 'Update Data',
      icon: Icons.cloud_upload_outlined,
      onPressed: isBlocked ? null : _save,
    );
  }
}

// ─── Edit Popup Form Sheet ──────────────────────────────────────────────────

class EditPopupFormSheet extends StatefulWidget {
  final ApiField parentField;
  final List<DynamicFieldModel> initialFields;
  final void Function(List<DynamicFieldModel> updated) onSaved;
  final VoidCallback? onFileDeleted;
  final Future<void> Function()? onCameraPhotoDeleted;
  final Future<bool> Function()? onRepeatableSubmitRequested;
  final DynamicFieldFormViewModel viewModel;
  final bool isEditMode;
  final bool showRepeatableLabels;

  const EditPopupFormSheet({
    super.key,
    required this.parentField,
    required this.initialFields,
    required this.onSaved,
    this.onFileDeleted,
    this.onCameraPhotoDeleted,
    this.onRepeatableSubmitRequested,
    required this.viewModel,
    this.isEditMode = true,
    this.showRepeatableLabels = false,
  });

  @override
  State<EditPopupFormSheet> createState() => _EditPopupFormSheetState();
}

class _EditPopupFormSheetState extends State<EditPopupFormSheet> {
  final _popupFormKey = GlobalKey<FormState>();
  AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;
  final Map<String, TextEditingController> _textCtrl = {};
  final Set<int> _selectedRepeatableIndexes = {};
  late List<DynamicFieldModel> _fields;
  bool _selectionMode = false;
  bool _isAutoSubmittingRepeatable = false;

  bool get _isRepeatablePopup => widget.parentField.isRepeatablePopupForm;
  bool get _usesRepeatableLabels =>
      _isRepeatablePopup || widget.showRepeatableLabels;
  bool get _disableRepeatableActions =>
      _isRepeatablePopup && (_selectionMode || _isAutoSubmittingRepeatable);
  String get _popupTitle => _usesRepeatableLabels
      ? getRepeatableDisplayLabel(widget.parentField)
      : widget.parentField.label;

  @override
  void initState() {
    super.initState();
    _fields = widget.initialFields.map((e) => e.copyWith()).toList();

    for (final df in _fields) {
      _ensureTextController(df);
    }
  }

  @override
  void dispose() {
    for (final c in _textCtrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool _isSubFieldVisible(DynamicFieldModel df) => shouldShowField(df, _fields);

  bool _isSubFieldRenderable(DynamicFieldModel df) =>
      !isDeletedRepeatableField(df) && _isSubFieldVisible(df);

  String _textKeyFor(DynamicFieldModel df) {
    if (!_usesRepeatableLabels) return df.field.key;
    final index = df.field.index ?? _fields.indexOf(df);
    return '${df.field.key}#$index#${df.field.fieldId}';
  }

  void _ensureTextController(DynamicFieldModel df) {
    final f = df.field;
    if (f.fieldStyle != FieldStyle.text &&
        f.fieldStyle != FieldStyle.number &&
        f.fieldStyle != FieldStyle.date) {
      return;
    }

    var initText = df.value?.toString() ?? '';
    if (f.fieldStyle == FieldStyle.date && initText.isNotEmpty) {
      initText = formatDateForDisplay(initText);
    }
    _textCtrl.putIfAbsent(
      _textKeyFor(df),
      () => TextEditingController(text: initText),
    );
  }

  void _onSubFieldChanged(DynamicFieldModel df, dynamic val) {
    setState(() {
      df.value = val;
      _resetHiddenSubFieldDependents(df.field.key);
    });
    widget.viewModel.handleSubfieldDependencyChange(df.field.key, _fields);
  }

  void _resetHiddenSubFieldDependents(String parentKey) {
    for (final df in _fields) {
      if (df.field.dependsOn == parentKey && df.field.hasVisibilityCondition) {
        if (!shouldShowField(df, _fields)) {
          df.value = null;
          df.previewUrl = null;
          _textCtrl[_textKeyFor(df)]?.clear();
          _resetHiddenSubFieldDependents(df.field.key);
        }
      }
    }
  }

  void _showLocalSnack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: success ? AppColors.primary : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
  }

  void _addMoreRepeatableItem() {
    final visibleFields = _fields.where(_isSubFieldRenderable).toList();
    final newIndex = nextRepeatableIndex(_fields);

    DynamicFieldModel? sourceModel;
    if (visibleFields.isNotEmpty) {
      sourceModel = visibleFields.last;
    }

    final DynamicFieldModel newField;
    if (sourceModel != null) {
      newField = cloneFieldForRepeatable(sourceModel, newIndex);
    } else {
      ApiField? template;
      for (final field in widget.parentField.subFields) {
        if (field.isDeleted != true) {
          template = field;
          break;
        }
      }
      if (template == null) {
        _showLocalSnack('No field template available to add more.');
        return;
      }
      newField = emptyDynamicFieldForRepeatableTemplate(template, newIndex);
    }

    setState(() {
      _fields.add(newField);
      _ensureTextController(newField);
      _selectionMode = false;
      _selectedRepeatableIndexes.clear();
    });
  }

  void _enterSelectionMode() {
    setState(() {
      _selectionMode = true;
      _selectedRepeatableIndexes.clear();
    });
  }

  void _cancelSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedRepeatableIndexes.clear();
    });
  }

  void _toggleRepeatableSelection(int index) {
    setState(() {
      if (_selectedRepeatableIndexes.contains(index)) {
        _selectedRepeatableIndexes.remove(index);
      } else {
        _selectedRepeatableIndexes.add(index);
      }
    });
  }

  DynamicFieldModel _markRepeatableDeleted(DynamicFieldModel field) {
    return field.copyWith(
      field: field.field.copyWith(isDeleted: true),
    );
  }

  Future<bool> _submitRepeatableChanges() async {
    if (!_isRepeatablePopup || !widget.isEditMode) return true;
    final submit = widget.onRepeatableSubmitRequested;
    if (submit == null) return true;

    setState(() => _isAutoSubmittingRepeatable = true);
    final success = await submit();
    if (mounted) {
      setState(() => _isAutoSubmittingRepeatable = false);
    }
    return success;
  }

  Future<void> _deleteSelectedRepeatableItems() async {
    if (_isAutoSubmittingRepeatable) return;

    if (_selectedRepeatableIndexes.isEmpty) {
      _showLocalSnack('Select at least one item to delete.');
      return;
    }

    final indexes = _selectedRepeatableIndexes.toList()
      ..sort((a, b) => b.compareTo(a));
    setState(() {
      for (final index in indexes) {
        if (index < 0 || index >= _fields.length) continue;
        if (widget.isEditMode) {
          _fields[index] = _markRepeatableDeleted(_fields[index]);
        } else {
          final removed = _fields.removeAt(index);
          _textCtrl.remove(_textKeyFor(removed))?.dispose();
        }
      }
      _selectionMode = false;
      _selectedRepeatableIndexes.clear();
    });

    if (_isRepeatablePopup && widget.isEditMode) {
      widget.onSaved(_fields);
      final success = await _submitRepeatableChanges();
      if (success && mounted) Navigator.pop(context);
    }
  }

  Future<void> _save() async {
    if (_isAutoSubmittingRepeatable) return;

    final isFormValid = _popupFormKey.currentState?.validate() ?? true;

    // Sync text controller values into field models before validation
    for (final df in _fields) {
      if (isDeletedRepeatableField(df)) {
        continue;
      }
      if (!_isSubFieldVisible(df)) {
        df.value = null;
        df.previewUrl = null;
        continue;
      }
      final textKey = _textKeyFor(df);
      if (_textCtrl.containsKey(textKey)) {
        final text = _textCtrl[textKey]!.text.trim();
        df.value = text.isNotEmpty ? text : null;
      }
    }

    // Recursive validation including nested popup children
    final textValues = Map.fromEntries(
      _textCtrl.entries.map((e) => MapEntry(e.key, e.value.text)),
    );
    final validationResult = validateFields(_fields, textValues: textValues);

    if (!validationResult.isValid) {
      setState(() => _autoValidateMode = AutovalidateMode.always);
      _showLocalSnack(
        'Please fill the required field: ${validationResult.firstInvalidLabel}',
      );
      return;
    }

    if (!isFormValid) {
      setState(() => _autoValidateMode = AutovalidateMode.always);
      _showLocalSnack('Please fix the errors in the form.');
      return;
    }

    widget.onSaved(_fields);
    if (_isRepeatablePopup && widget.isEditMode) {
      final success = await _submitRepeatableChanges();
      if (success && mounted) Navigator.pop(context);
      return;
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        builder: (_, ctrl) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Scaffold(
            backgroundColor: Colors.white,
            body: Stack(
              children: [
                Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                      child: Row(
                        children: [
                          const Icon(Icons.edit_outlined,
                              color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _popupTitle,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary),
                            ),
                          ),
                          if (_isRepeatablePopup && _selectionMode) ...[
                            TextButton(
                              onPressed: () => _deleteSelectedRepeatableItems(),
                              child: const Text(
                                'Delete',
                                style: TextStyle(color: AppColors.error),
                              ),
                            ),
                            TextButton(
                              onPressed: _cancelSelectionMode,
                              child: const Text('Cancel'),
                            ),
                          ] else if (_isRepeatablePopup)
                            IconButton(
                              onPressed: _enterSelectionMode,
                              icon: const Icon(Icons.delete_outline,
                                  color: AppColors.error),
                            ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close,
                                color: AppColors.textMedium),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: Form(
                        key: _popupFormKey,
                        autovalidateMode: _autoValidateMode,
                        child: SingleChildScrollView(
                          controller: ctrl,
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              ..._fields
                                  .where((df) => _isSubFieldRenderable(df))
                                  .map((df) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 14),
                                        child: _buildRepeatableShell(df),
                                      )),
                              const SizedBox(height: 8),
                              if (_isRepeatablePopup) ...[
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: OutlinedButton.icon(
                                      onPressed: _disableRepeatableActions
                                          ? null
                                          : _addMoreRepeatableItem,
                                      icon: const Icon(Icons.add),
                                      label: const Text('Add More'),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed:
                                      _disableRepeatableActions ? null : _save,
                                  icon: const Icon(Icons.check),
                                  label: const Text('Done'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_isAutoSubmittingRepeatable)
                  Positioned.fill(
                    child: AbsorbPointer(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.45),
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: Colors.white),
                              SizedBox(height: 12),
                              Text(
                                'Updating...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _captureAndUploadSubField(DynamicFieldModel df) async {
    final localPath = await Navigator.pushNamed(
      context,
      '/camera-capture',
      arguments: const {'requiresLocation': true},
    ) as String?;
    if (localPath == null || !mounted) return;

    final result =
        await widget.viewModel.uploadImageOnly(df.field.key, localPath);
    if (!mounted) return;

    if (result != null) {
      setState(() {
        df.value = result.imagePath;
        df.previewUrl = result.previewUrl;
      });
      _showLocalSnack('Photo uploaded successfully', success: true);
    } else {
      _showLocalSnack(
        widget.viewModel.lastUploadErrorMessage ??
            'Photo upload failed. Please try again.',
      );
    }
  }

  Future<void> _pickAndUploadSubFieldFiles(DynamicFieldModel df) async {
    final localPaths = await pickDynamicUploadFiles(
      context,
      requiresLocationForCamera: true,
    );
    if (localPaths.isEmpty || !mounted) return;

    final result =
        await widget.viewModel.uploadFilesOnly(df.field.key, localPaths);
    if (!mounted) return;

    if (result == null) {
      _showLocalSnack(
        widget.viewModel.lastUploadErrorMessage ??
            'File upload failed. Please try again.',
      );
      return;
    }

    setState(() {
      df.appendFileReferences(
        paths: result.paths,
        previewUrls: result.previewUrls,
      );
    });
    if (result.hasIncompleteData) {
      _showLocalSnack('Files uploaded, but some previews are unavailable.',
          success: true);
    } else {
      _showLocalSnack('Files uploaded successfully', success: true);
    }
  }

  Future<void> _deleteSubFieldFile(
    DynamicFieldModel df,
    AppFileItem file,
  ) async {
    final path = file.remotePath?.trim() ?? '';
    await widget.viewModel.deleteFileOnly(
      df.field.key,
      path,
      fieldId: df.field.fieldId,
    );
    if (!mounted) return;

    setState(() {
      df.removeFileReferenceByPath(path);
    });
    widget.onSaved(_fields);
    widget.onFileDeleted?.call();
  }

  Future<void> _deleteSubFieldPhoto(DynamicFieldModel df) async {
    final confirmed = await showPopupConfirm(
      context,
      title: 'Remove photo?',
      message: 'Remove this photo? This action cannot be undone.',
      confirmLabel: 'Remove',
      confirmColor: AppColors.error,
      icon: Icons.delete_outline,
    );
    if (confirmed != true || !mounted) return;

    final path = df.value?.toString().trim() ?? '';
    try {
      await widget.viewModel.deleteFileOnly(
        df.field.key,
        path,
        fieldId: df.field.fieldId,
      );
      if (!mounted) return;

      setState(() {
        df.value = null;
        df.previewUrl = null;
      });
      widget.onSaved(_fields);
      widget.onFileDeleted?.call();
      await widget.onCameraPhotoDeleted?.call();
      if (!mounted) return;
      _showLocalSnack('Photo removed successfully', success: true);
    } catch (_) {
      if (mounted) {
        _showLocalSnack('Unable to remove photo. Please try again.');
      }
    }
  }

  void _clearSubFieldPhoto(DynamicFieldModel df) {
    setState(() {
      df.value = null;
      df.previewUrl = null;
    });
  }

  Widget _buildRepeatableShell(DynamicFieldModel df) {
    if (!_isRepeatablePopup) return _buildSubField(df);

    final index = _fields.indexOf(df);
    final selected = _selectedRepeatableIndexes.contains(index);
    return InkWell(
      onTap: _selectionMode ? () => _toggleRepeatableSelection(index) : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.08)
              : AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.light,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_selectionMode) ...[
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected ? AppColors.primary : AppColors.textMedium,
              ),
              const SizedBox(width: 10),
            ],
            Expanded(child: _buildSubField(df)),
          ],
        ),
      ),
    );
  }

  Widget _buildSubField(DynamicFieldModel df) {
    final f = df.field;

    int? popupFormFilled;
    int? popupFormTotal;
    if (f.isFormContainer) {
      final subFields = df.value as List<DynamicFieldModel>? ?? [];
      popupFormTotal = getTotalCount(subFields);
      popupFormFilled = getFilledCount(subFields);
    }

    final isCameraField = f.fieldStyle == FieldStyle.camera;
    final isFileField = f.fieldStyle == FieldStyle.file;
    final textKey = _textKeyFor(df);

    return DynamicFieldBuilder(
      field: f,
      value:
          _textCtrl.containsKey(textKey) ? _textCtrl[textKey]!.text : df.value,
      textController: _textCtrl[textKey],
      accentColor: AppColors.primary,
      hasError: df.hasError,
      errorMessage: df.errorMessage,
      displayLabel: getRepeatableFormContainerDisplayLabel(
        f,
        _usesRepeatableLabels,
      ),
      onChanged: (val) {
        if (!_textCtrl.containsKey(textKey)) {
          _onSubFieldChanged(df, val);
        } else {
          setState(
              () {}); // text controller manages value; rebuild for visibility
        }
      },
      onPopupFormPressed:
          f.isFormContainer ? () => _openNestedPopupForm(df) : null,
      popupFormFilledCount: popupFormFilled,
      popupFormTotalCount: popupFormTotal,
      onMapPolygonPressed: f.fieldStyle == FieldStyle.mapPolygon
          ? () => _openMapForNested(df)
          : null,
      previewUrl: (isCameraField || isFileField) ? df.previewUrl : null,
      isUploading: (isCameraField || isFileField)
          ? widget.viewModel.isFieldUploading(f.key)
          : false,
      onCapturePhoto:
          isCameraField ? () => _captureAndUploadSubField(df) : null,
      onClearPhoto: isCameraField ? () => _clearSubFieldPhoto(df) : null,
      onDeleteCameraPhoto:
          isCameraField ? () => _deleteSubFieldPhoto(df) : null,
      onAddFiles: isFileField ? () => _pickAndUploadSubFieldFiles(df) : null,
      onDeleteFile:
          isFileField ? (file) => _deleteSubFieldFile(df, file) : null,
      resolvedOptions:
          f.fieldStyle == FieldStyle.dropdown ? df.resolvedOptions : null,
      isLoadingOptions:
          f.fieldStyle == FieldStyle.dropdown ? df.isLoadingOptions : false,
      optionsError:
          f.fieldStyle == FieldStyle.dropdown ? df.optionsError : null,
      onRetryOptions:
          f.fieldStyle == FieldStyle.dropdown && df.optionsError != null
              ? () => widget.viewModel.retrySubfieldOptions(f.key, _fields)
              : null,
    );
  }

  Future<void> _openMapForNested(DynamicFieldModel df) async {
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
      debugPrint('=== MAP RESULT (Nested Field: ${df.field.key}) ===');
      debugPrint('Raw result: $result');
      debugPrint('Cleaned coordinates (to be saved in value): $coordinates');
      setState(() => df.value = coordinates);
    }
  }

  void _openNestedPopupForm(DynamicFieldModel df) {
    final currentValues = df.value as List<DynamicFieldModel>? ?? [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditPopupFormSheet(
        parentField: df.field,
        initialFields: currentValues,
        onSaved: (result) {
          setState(() => df.value = result);
          df.clearError();
        },
        onRepeatableSubmitRequested: () async {
          widget.onSaved(_fields);
          return await widget.onRepeatableSubmitRequested?.call() ?? false;
        },
        onFileDeleted: widget.onFileDeleted,
        onCameraPhotoDeleted: widget.onCameraPhotoDeleted,
        viewModel: widget.viewModel,
        isEditMode: widget.isEditMode,
        showRepeatableLabels: _usesRepeatableLabels,
      ),
    );
  }
}
