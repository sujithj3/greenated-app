import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_constants.dart';
import '../../models/api/api_models.dart';
import '../../services/auth_service.dart';
import '../../utils/field_fill_state.dart';
import '../../services/form_config_service.dart';
import '../../services/image_upload_service.dart';
import '../../services/registration_form_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/form_validator.dart';
import '../../utils/snack_bar_helper.dart';
import '../../core/network/api_client.dart';
import '../../view_models/farmer/farmer_form_view_model.dart';
import '../../widgets/dynamic_field_builder.dart';
import '../../widgets/shimmer_loading.dart';

class FarmerFormView extends StatefulWidget {
  const FarmerFormView({super.key});

  @override
  State<FarmerFormView> createState() => _FarmerFormViewState();
}

class _FarmerFormViewState extends State<FarmerFormView> {
  final _formKey = GlobalKey<FormState>();

  late final FarmerFormViewModel _vm;
  bool _isInit = false;
  AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;

  // ── Flutter-owned controllers (stay in View) ─────────────────────────────
  final _landAreaCtrl = TextEditingController();
  final Map<String, TextEditingController> _dynTextCtrl = {};

  @override
  void initState() {
    super.initState();
    _vm = FarmerFormViewModel(
      context.read<FormConfigService>(),
      context.read<RegistrationFormService>(),
      context.read<AuthService>(),
      context.read<ImageUploadService>(),
      context.read<ApiClient>(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) return;
    _isInit = true;

    // initFromArgs is idempotent — safe to call here
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    _vm.initFromArgs(args);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        await _vm.ensureCategoriesLoaded();
        if (mounted) await _vm.loadForm();
        if (mounted) _syncTextControllers();
      }
    });
  }

  @override
  void dispose() {
    _landAreaCtrl.dispose();
    for (final c in _dynTextCtrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Sync text controllers after form load / populate ─────────────────────

  void _syncTextControllers() {
    // Dispose any old controllers for keys no longer present
    final currentKeys = _vm.dynamicFields.map((df) => df.field.key).toSet();
    _dynTextCtrl.removeWhere((key, ctrl) {
      if (!currentKeys.contains(key)) {
        ctrl.dispose();
        return true;
      }
      return false;
    });

    // Create / update controllers for text-type fields
    for (final df in _vm.dynamicFields) {
      final f = df.field;
      if (f.fieldStyle == FieldStyle.text ||
          f.fieldStyle == FieldStyle.number ||
          f.fieldStyle == FieldStyle.date) {
        var initial = _vm.initialTextFor(f.key);
        if (f.fieldStyle == FieldStyle.date && initial.isNotEmpty) {
          initial = formatDateForDisplay(initial);
        }
        if (!_dynTextCtrl.containsKey(f.key)) {
          _dynTextCtrl[f.key] = TextEditingController(text: initial);
        } else {
          if (initial.isNotEmpty) {
            _dynTextCtrl[f.key]!.text = initial;
          }
        }
      }
    }

    // Clear text controllers for fields that are now hidden
    for (final df in _vm.dynamicFields) {
      if (!_vm.isFieldVisible(df) && _dynTextCtrl.containsKey(df.field.key)) {
        _dynTextCtrl[df.field.key]!.clear();
      }
    }

    setState(() {});
  }

  // ── Land map ──────────────────────────────────────────────────────────────

  Future<void> _openMap() async {
    final result = await Navigator.pushNamed(
      context,
      '/land-measurement',
      arguments: {
        'initialPolygon': _vm.landCoordinates,
        'onClear': () {
          _vm.setLandResult({'area': 0.0, 'coordinates': []});
          _landAreaCtrl.clear();
          if (mounted) {
            context.showSnack('Land measurement removed', success: true);
          }
        }
      },
    ) as Map<String, dynamic>?;
    if (result != null && mounted) {
      final area = result['area'] as double? ?? 0;
      _vm.setLandResult(result);
      if (area > 0) {
        _landAreaCtrl.text = area.toStringAsFixed(4);
      } else {
        _landAreaCtrl.clear();
      }
      if (mounted) {
        if (area > 0) {
          context.showSnack('Area: ${area.toStringAsFixed(4)} acres',
              success: true);
        } else {
          context.showSnack('Land measurement removed', success: true);
        }
      }
    }
  }

  // ── Dynamic Map Polygon ───────────────────────────────────────────────────

  Future<void> _openMapForDynamicField(DynamicFieldModel df) async {
    final result = await Navigator.pushNamed(
      context,
      '/land-measurement',
      arguments: {
        'initialPolygon': df.value,
        'onClear': () {
          _vm.updateDynamicFieldValue(df.field.key, null);
          if (mounted) context.showSnack('Polygon removed', success: true);
        }
      },
    ) as Map<String, dynamic>?;
    if (result != null && mounted) {
      final rawCoords = result['coordinates'] as List<dynamic>? ?? [];
      final coords =
          rawCoords.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      _vm.updateDynamicFieldValue(df.field.key, coords.isEmpty ? null : coords);
      if (mounted) {
        if (coords.isEmpty) {
          context.showSnack('Polygon removed', success: true);
        } else {
          context.showSnack('Polygon saved (${coords.length} points)',
              success: true);
        }
      }
    }
  }

  // ── Camera capture + upload (dynamic field driven) ─────────────────────

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

  // ── Popup form sheet ──────────────────────────────────────────────────────

  void _openPopupFormSheet(DynamicFieldModel df, Color catColor) {
    final currentValues = df.value as List<DynamicFieldModel>? ?? [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PopupFormSheet(
        parentField: df.field,
        catColor: catColor,
        initialFields: currentValues,
        onSaved: (result) {
          _vm.updateDynamicFieldValue(df.field.key, result);
          // Clear parent error after popup is saved
          df.clearError();
          if (mounted) setState(() {});
        },
        viewModel: _vm,
      ),
    );
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    // 1. Trigger widget-level validation to show inline error text for on-screen fields
    final isFormValid = _formKey.currentState?.validate() ?? true;

    if (_vm.selectedCategory.isEmpty) {
      context.showSnack('Select a category.');
      return;
    }
    if (_vm.selectedSubcategory.isEmpty) {
      context.showSnack('Select a subcategory.');
      return;
    }

    final textValues = Map.fromEntries(
      _dynTextCtrl.entries.map((e) => MapEntry(e.key, e.value.text)),
    );

    // 2. Recursive validation for all visible fields including popup children
    final visibleFields =
        _vm.dynamicFields.where((df) => _vm.isFieldVisible(df)).toList();
    final validationResult = validateFields(
      visibleFields,
      textValues: textValues,
    );

    if (!validationResult.isValid) {
      if (mounted) {
        setState(() => _autoValidateMode = AutovalidateMode.always);
        context.showSnack(
          'Please fill the required field: ${validationResult.firstInvalidLabel}',
        );
      }
      return;
    }

    // 3. Check that any data exists at all
    bool hasData = false;
    for (final df in visibleFields) {
      dynamic v;
      if (textValues.containsKey(df.field.key)) {
        v = textValues[df.field.key]!.trim();
        if ((v as String).isEmpty) v = null;
      } else {
        v = df.value;
      }
      if (v != null) {
        if (v is String && v.isNotEmpty) hasData = true;
        if (v is num || v is bool) hasData = true;
        if (v is List && v.isNotEmpty) {
          if (df.field.isPopupForm && v is List<DynamicFieldModel>) {
            for (final subDf in v) {
              if (subDf.value != null &&
                  subDf.value.toString().trim().isNotEmpty) {
                hasData = true;
                break;
              }
            }
          } else {
            hasData = true;
          }
        }
      }
    }

    if (_vm.geoRequired) {
      if (_landAreaCtrl.text.trim().isEmpty) {
        if (mounted) {
          setState(() => _autoValidateMode = AutovalidateMode.always);
          context.showSnack('Please complete the required field: Land Area');
        }
        return;
      } else {
        hasData = true;
      }
    }

    if (!hasData && visibleFields.isNotEmpty) {
      if (mounted) {
        setState(() => _autoValidateMode = AutovalidateMode.always);
        context.showSnack('Please fill at least one field to submit.');
      }
      return;
    }

    if (!isFormValid) {
      if (mounted) {
        setState(() => _autoValidateMode = AutovalidateMode.always);
        context.showSnack('Please fix the errors in the form.');
      }
      return;
    }

    try {
      final success = await _vm.save(
        textValues: textValues,
        landAreaText: _landAreaCtrl.text,
      );
      if (success && mounted) {
        context.showSnack('Farmer registered!', success: true);
        Navigator.pushNamedAndRemoveUntil(
            context, '/dashboard', (route) => false);
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
        final catData = AppCategories.styleFor(_vm.selectedCategory);
        final catColor = catData?.color ?? AppColors.primary;

        final isUploading =
            _vm.dynamicFields.any((df) => _vm.isFieldUploading(df.field.key));
        final showOverlay =
            _vm.isSaving || _vm.dynamicFields.any((df) => df.isLoadingOptions);
        final isBlocked = showOverlay || isUploading;

        return Stack(
          children: [
            Scaffold(
              appBar: AppBar(
                title: const Text('New Registration'),
              ),
              body: _vm.isLoadingForm
                  ? const ShimmerFormSkeleton()
                  : _vm.formLoadError != null && _vm.dynamicFields.isEmpty
                      ? _FormLoadErrorState(
                          message: _vm.formLoadError!,
                          onRetry: _vm.loadForm,
                        )
                      : Form(
                          key: _formKey,
                          autovalidateMode: _autoValidateMode,
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              if (_vm.selectedCategory.isNotEmpty) ...[
                                _buildCategoryBadge(catColor, catData),
                                const SizedBox(height: 20),
                              ],
                              ..._buildDynamicFields(catColor),
                              if (_vm.geoRequired) ...[
                                const SizedBox(height: 24),
                                _Section(
                                    title: 'Land Details',
                                    icon: Icons.landscape_outlined),
                                const SizedBox(height: 12),
                                ..._buildLandSection(),
                              ],
                              const SizedBox(height: 32),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: isBlocked ? null : _save,
                                  icon: const Icon(Icons.how_to_reg),
                                  label: const Text('Complete Registration'),
                                ),
                              ),
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
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
        );
      },
    );
  }

  Widget _buildCategoryBadge(Color catColor, CategoryData? catData) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: catColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: catColor.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: catColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              catData?.icon ?? Icons.category_outlined,
              color: catColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _vm.selectedCategory,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: catColor,
                  ),
                ),
                if (_vm.selectedSubcategory.isNotEmpty)
                  Text(
                    _vm.selectedSubcategory,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMedium),
                  ),
              ],
            ),
          ),
          Icon(Icons.check_circle, color: catColor, size: 22),
        ],
      ),
    );
  }

  List<Widget> _buildDynamicFields(Color catColor) {
    if (_vm.dynamicFields.isEmpty) return [];
    return _vm.dynamicFields
        .where((df) => _vm.isFieldVisible(df))
        .map((df) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildDynamicField(df, catColor),
            ))
        .toList();
  }

  Widget _buildDynamicField(DynamicFieldModel df, Color catColor) {
    final f = df.field;
    int? popupFormFilled;
    int? popupFormTotal;
    if (f.isPopupForm) {
      final subFieldsList = df.value as List<DynamicFieldModel>? ?? [];
      popupFormTotal = getTotalCount(subFieldsList);
      popupFormFilled = getFilledCount(subFieldsList);
    }

    final isCameraField = f.fieldStyle == FieldStyle.camera ||
        f.fieldStyle == FieldStyle.cameraFile;

    return DynamicFieldBuilder(
      field: f,
      value: df.value,
      textController: _dynTextCtrl[f.key],
      accentColor: catColor,
      hasError: df.hasError,
      errorMessage: df.errorMessage,
      onChanged: (val) => _vm.updateDynamicFieldValue(f.key, val),
      onPopupFormPressed:
          f.isPopupForm ? () => _openPopupFormSheet(df, catColor) : null,
      popupFormFilledCount: popupFormFilled,
      popupFormTotalCount: popupFormTotal,
      // Camera field wiring
      isUploading: isCameraField ? _vm.isFieldUploading(f.key) : false,
      onCapturePhoto: isCameraField ? () => _captureAndUpload(f.key) : null,
      onClearPhoto: isCameraField ? () => _vm.clearCameraImage(f.key) : null,
      previewUrl: isCameraField ? df.previewUrl : null,
      onMapPolygonPressed: f.fieldStyle == FieldStyle.mapPolygon
          ? () => _openMapForDynamicField(df)
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

  List<Widget> _buildLandSection() {
    return [
      OutlinedButton.icon(
        onPressed: _openMap,
        icon: const Icon(Icons.map),
        label: Text(_vm.landCoordinates.isEmpty
            ? 'Measure Land on Map'
            : 'Re-measure  (${_vm.landCoordinates.length} pts)'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
        ),
      ),
      const SizedBox(height: 12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: _landAreaCtrl,
              decoration: const InputDecoration(
                labelText: 'Land Area *',
                prefixIcon: Icon(Icons.square_foot_outlined),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (double.tryParse(v) == null) return 'Invalid';
                return null;
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              initialValue: _vm.selectedLandUnit,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Unit'),
              items: _vm.landUnits
                  .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                  .toList(),
              onChanged: (v) => _vm.setLandUnit(v!),
            ),
          ),
        ],
      ),
    ];
  }
}

// ─── Error State ──────────────────────────────────────────────────────────────

class _FormLoadErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _FormLoadErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
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
              'Unable to load registration fields',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.dark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(message,
                style: const TextStyle(color: AppColors.textMedium),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  const _Section({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: AppColors.primary, size: 18),
      const SizedBox(width: 8),
      Text(title,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.dark)),
      const SizedBox(width: 8),
      Expanded(
          child: Divider(
              color: AppColors.primary.withValues(alpha: 0.35),
              thickness: 1.5)),
    ]);
  }
}

// ─── Popup Form Sheet ─────────────────────────────────────────────────────────

class _PopupFormSheet extends StatefulWidget {
  final ApiField parentField;
  final Color catColor;
  final List<DynamicFieldModel> initialFields;
  final void Function(List<DynamicFieldModel> updated) onSaved;
  final FarmerFormViewModel viewModel;

  const _PopupFormSheet({
    required this.parentField,
    required this.catColor,
    required this.initialFields,
    required this.onSaved,
    required this.viewModel,
  });

  @override
  State<_PopupFormSheet> createState() => _PopupFormSheetState();
}

class _PopupFormSheetState extends State<_PopupFormSheet> {
  final _popupFormKey = GlobalKey<FormState>();
  AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;
  final Map<String, TextEditingController> _textCtrl = {};
  late List<DynamicFieldModel> _fields;

  @override
  void initState() {
    super.initState();
    _fields = widget.initialFields.map((e) => e.copyWith()).toList();

    for (final df in _fields) {
      final f = df.field;
      var initText = df.value?.toString() ?? '';
      if (f.fieldStyle == FieldStyle.date && initText.isNotEmpty) {
        initText = formatDateForDisplay(initText);
      }
      if (f.fieldStyle == FieldStyle.text ||
          f.fieldStyle == FieldStyle.number ||
          f.fieldStyle == FieldStyle.date) {
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
    widget.viewModel.handleSubfieldDependencyChange(df.field.key, _fields);
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

  void _save() {
    final isFormValid = _popupFormKey.currentState?.validate() ?? true;

    // Sync text controller values into field models before validation
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
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.catColor;
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
            body: Column(
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
                      Icon(Icons.tune, color: color, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.parentField.label,
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: color),
                        ),
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
                              .where((df) => _isSubFieldVisible(df))
                              .map((df) => Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: _buildSubField(df, color),
                                  )),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _save,
                              icon: const Icon(Icons.check),
                              label: const Text('Done'),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: color),
                            ),
                          ),
                        ],
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
    final localPath =
        await Navigator.pushNamed(context, '/camera-capture') as String?;
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
      _showLocalSnack('Photo upload failed. Please try again.');
    }
  }

  void _clearSubFieldPhoto(DynamicFieldModel df) {
    setState(() {
      df.value = null;
      df.previewUrl = null;
    });
  }

  Widget _buildSubField(DynamicFieldModel df, Color color) {
    final f = df.field;
    int? popupFormFilled;
    int? popupFormTotal;
    if (f.isPopupForm) {
      final subFieldsList = df.value as List<DynamicFieldModel>? ?? [];
      popupFormTotal = getTotalCount(subFieldsList);
      popupFormFilled = getFilledCount(subFieldsList);
    }

    final isCameraField = f.fieldStyle == FieldStyle.camera ||
        f.fieldStyle == FieldStyle.cameraFile;

    return DynamicFieldBuilder(
      field: f,
      value: _textCtrl.containsKey(f.key) ? _textCtrl[f.key]!.text : df.value,
      textController: _textCtrl[f.key],
      accentColor: color,
      hasError: df.hasError,
      errorMessage: df.errorMessage,
      onChanged: (val) {
        if (!_textCtrl.containsKey(f.key)) {
          _onSubFieldChanged(df, val);
        } else {
          setState(
              () {}); // text controller manages value; rebuild for visibility
        }
      },
      onPopupFormPressed:
          f.isPopupForm ? () => _openNestedPopupForm(df, color) : null,
      popupFormFilledCount: popupFormFilled,
      popupFormTotalCount: popupFormTotal,
      onMapPolygonPressed: f.fieldStyle == FieldStyle.mapPolygon
          ? () => _openMapForNestedDynamicField(df)
          : null,
      previewUrl: isCameraField ? df.previewUrl : null,
      isUploading:
          isCameraField ? widget.viewModel.isFieldUploading(f.key) : false,
      onCapturePhoto:
          isCameraField ? () => _captureAndUploadSubField(df) : null,
      onClearPhoto: isCameraField ? () => _clearSubFieldPhoto(df) : null,
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

  Future<void> _openMapForNestedDynamicField(DynamicFieldModel df) async {
    final result = await Navigator.pushNamed(
      context,
      '/land-measurement',
      arguments: {
        'initialPolygon': df.value,
        'onClear': () {
          if (mounted) setState(() => df.value = null);
        }
      },
    ) as Map<String, dynamic>?;
    if (result != null && mounted) {
      final rawCoords = result['coordinates'] as List<dynamic>? ?? [];
      final coords =
          rawCoords.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      setState(() => df.value = coords.isEmpty ? null : coords);
    }
  }

  void _openNestedPopupForm(DynamicFieldModel df, Color color) {
    final currentValues = df.value as List<DynamicFieldModel>? ?? [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PopupFormSheet(
        parentField: df.field,
        catColor: color,
        initialFields: currentValues,
        onSaved: (result) {
          setState(() => df.value = result);
          df.clearError();
        },
        viewModel: widget.viewModel,
      ),
    );
  }
}
