import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../models/api/api_models.dart';
import '../../services/auth_service.dart';
import '../../services/image_upload_service.dart';
import '../../services/registration_form_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/snack_bar_helper.dart';
import '../../view_models/farmer/edit_farmer_details_view_model.dart';
import '../../widgets/dynamic_field_builder.dart';
import '../../widgets/shimmer_loading.dart';

/// Edit view for a previously submitted farmer registration.
///
/// Fetches prefilled form data via the `form-edit` GET endpoint and renders
/// an editable dynamic form. Maintains fully independent state from the
/// create and detail flows.
class EditFarmerDetailsView extends StatefulWidget {
  final int subcategoryId;
  final int submissionId;

  const EditFarmerDetailsView({
    super.key,
    required this.subcategoryId,
    required this.submissionId,
  });

  @override
  State<EditFarmerDetailsView> createState() => _EditFarmerDetailsViewState();
}

class _EditFarmerDetailsViewState extends State<EditFarmerDetailsView> {
  late final EditFarmerDetailsViewModel _vm;
  final Map<String, TextEditingController> _textCtrl = {};
  bool _isInit = false;

  @override
  void initState() {
    super.initState();
    _vm = EditFarmerDetailsViewModel(
      service: context.read<RegistrationFormService>(),
      authService: context.read<AuthService>(),
      apiClient: context.read<ApiClient>(),
      imageUploadService: context.read<ImageUploadService>(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) return;
    _isInit = true;

    _vm.addListener(_onVmChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        await _vm.loadEditForm(
          subcategoryId: widget.subcategoryId,
          submissionId: widget.submissionId,
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
    for (final c in _textCtrl.values) {
      c.dispose();
    }
    _vm.dispose();
    super.dispose();
  }

  // ── Camera capture + upload ─────────────────────────────────────────────

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

  // ── Popup Form Sheet (view + edit) ──────────────────────────────────────

  Future<void> _openEditPopupSheet(DynamicFieldModel df) async {
    final currentValues = df.value as List<DynamicFieldModel>? ?? [];
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditPopupFormSheet(
        parentField: df.field,
        initialFields: currentValues,
        onSaved: (result) => _vm.updateFieldValue(df.field.key, result),
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

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final textValues = Map.fromEntries(
      _textCtrl.entries.map((e) => MapEntry(e.key, e.value.text)),
    );

    try {
      final success = await _vm.save(
        textValues: textValues,
        subcategoryId: widget.subcategoryId,
        submissionId: widget.submissionId,
      );
      if (success && mounted) {
        context.showSnack('Registration updated!', success: true);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) context.showSnack('Error: ${e.toString()}');
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        final isBlocked = _vm.isSaving ||
            _vm.fields.any((df) => _vm.isFieldUploading(df.field.key)) ||
            _vm.fields.any((df) => df.isLoadingOptions);

        return Stack(
          children: [
            Scaffold(
              appBar: AppBar(
                title: Text(
                    _vm.formName.isNotEmpty ? 'Edit ${_vm.formName}' : 'Edit'),
              ),
              body: _buildBody(isBlocked),
            ),
            if (isBlocked)
              AbsorbPointer(
                absorbing: true,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.45),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ),
          ],
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
                  submissionId: widget.submissionId,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_vm.fields.isEmpty) {
      return const Center(
        child: Text('No data available',
            style: TextStyle(color: AppColors.textMedium, fontSize: 16)),
      );
    }

    final visibleFields =
        _vm.fields.where((df) => _vm.isFieldVisible(df)).toList();

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: visibleFields.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _buildField(visibleFields[index]),
          ),
        ),
        _buildSubmitButton(isBlocked),
      ],
    );
  }

  Widget _buildField(DynamicFieldModel df) {
    final f = df.field;

    int? popupFormFilled;
    int? popupFormTotal;
    if (f.isPopupForm) {
      final subFields = df.value as List<DynamicFieldModel>? ?? [];
      popupFormTotal = subFields.length;
      popupFormFilled =
          subFields.where((e) => e.value != null && e.value != '').length;
    }

    final isCameraField = f.fieldStyle == FieldStyle.camera ||
        f.fieldStyle == FieldStyle.cameraFile;

    return DynamicFieldBuilder(
      field: f,
      value: _textCtrl.containsKey(f.key) ? _textCtrl[f.key]!.text : df.value,
      textController: _textCtrl[f.key],
      accentColor: AppColors.primary,
      onChanged: (val) {
        _vm.updateFieldValue(f.key, val);
      },
      onPopupFormPressed: f.isPopupForm ? () => _openEditPopupSheet(df) : null,
      popupFormFilledCount: popupFormFilled,
      popupFormTotalCount: popupFormTotal,
      // Camera field wiring
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

  Widget _buildSubmitButton(bool isBlocked) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: isBlocked ? null : _save,
        icon: const Icon(Icons.cloud_upload_outlined),
        label: const Text('Update Registration'),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
        ),
      ),
    );
  }
}

// ─── Edit Popup Form Sheet ──────────────────────────────────────────────────

class _EditPopupFormSheet extends StatefulWidget {
  final ApiField parentField;
  final List<DynamicFieldModel> initialFields;
  final void Function(List<DynamicFieldModel> updated) onSaved;

  const _EditPopupFormSheet({
    required this.parentField,
    required this.initialFields,
    required this.onSaved,
  });

  @override
  State<_EditPopupFormSheet> createState() => _EditPopupFormSheetState();
}

class _EditPopupFormSheetState extends State<_EditPopupFormSheet> {
  final Map<String, TextEditingController> _textCtrl = {};
  late List<DynamicFieldModel> _fields;

  @override
  void initState() {
    super.initState();
    _fields = widget.initialFields.map((e) => e.copyWith()).toList();

    for (final df in _fields) {
      final f = df.field;
      if (f.fieldStyle == FieldStyle.text ||
          f.fieldStyle == FieldStyle.number ||
          f.fieldStyle == FieldStyle.date) {
        var initText = df.value?.toString() ?? '';
        if (f.fieldStyle == FieldStyle.date && initText.isNotEmpty) {
          initText = formatDateForDisplay(initText);
        }
        _textCtrl[f.key] = TextEditingController(text: initText);
      }
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

  void _onSubFieldChanged(DynamicFieldModel df, dynamic val) {
    setState(() {
      df.value = val;
      _resetHiddenSubFieldDependents(df.field.key);
    });
  }

  void _resetHiddenSubFieldDependents(String parentKey) {
    for (final df in _fields) {
      if (df.field.dependsOn == parentKey && df.field.hasVisibilityCondition) {
        if (!shouldShowField(df, _fields)) {
          df.value = null;
          df.previewUrl = null;
          _textCtrl[df.field.key]?.clear();
          _resetHiddenSubFieldDependents(df.field.key);
        }
      }
    }
  }

  void _save() {
    for (final df in _fields) {
      if (!_isSubFieldVisible(df)) {
        df.value = null;
        df.previewUrl = null;
        continue;
      }
      if (_textCtrl.containsKey(df.field.key)) {
        final text = _textCtrl[df.field.key]!.text.trim();
        df.value = text.isNotEmpty ? text : null;
      }
    }
    widget.onSaved(_fields);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      maxChildSize: 0.92,
      minChildSize: 0.35,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
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
                      widget.parentField.label,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppColors.textMedium),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: ctrl,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    ..._fields
                        .where((df) => _isSubFieldVisible(df))
                        .map((df) => Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _buildSubField(df),
                            )),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.check),
                        label: const Text('Done'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubField(DynamicFieldModel df) {
    final f = df.field;

    int? popupFormFilled;
    int? popupFormTotal;
    if (f.isPopupForm) {
      final subFields = df.value as List<DynamicFieldModel>? ?? [];
      popupFormTotal = subFields.length;
      popupFormFilled =
          subFields.where((e) => e.value != null && e.value != '').length;
    }

    final isCameraField =
        f.fieldStyle == FieldStyle.camera || f.fieldStyle == FieldStyle.cameraFile;

    return DynamicFieldBuilder(
      field: f,
      value: _textCtrl.containsKey(f.key) ? _textCtrl[f.key]!.text : df.value,
      textController: _textCtrl[f.key],
      accentColor: AppColors.primary,
      onChanged: (val) {
        if (!_textCtrl.containsKey(f.key)) {
          _onSubFieldChanged(df, val);
        } else {
          setState(() {}); // text controller manages value; rebuild for visibility
        }
      },
      onPopupFormPressed: f.isPopupForm ? () => _openNestedPopupForm(df) : null,
      popupFormFilledCount: popupFormFilled,
      popupFormTotalCount: popupFormTotal,
      onMapPolygonPressed: f.fieldStyle == FieldStyle.mapPolygon
          ? () => _openMapForNested(df)
          : null,
      previewUrl: isCameraField ? df.previewUrl : null,
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
      builder: (_) => _EditPopupFormSheet(
        parentField: df.field,
        initialFields: currentValues,
        onSaved: (result) => setState(() => df.value = result),
      ),
    );
  }
}
