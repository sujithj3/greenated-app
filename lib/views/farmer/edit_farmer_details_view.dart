import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/api/api_models.dart';
import '../../services/auth_service.dart';
import '../../services/registration_form_service.dart';
import '../../utils/app_colors.dart';
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
        final initial = df.value?.toString() ?? '';
        if (!_textCtrl.containsKey(f.key)) {
          _textCtrl[f.key] = TextEditingController(text: initial);
        } else if (initial.isNotEmpty && _textCtrl[f.key]!.text.isEmpty) {
          _textCtrl[f.key]!.text = initial;
        }
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
    await Navigator.pushNamed(
      context,
      '/land-measurement',
      arguments: {
        'initialPolygon': df.value,
        'viewOnly': false,
      },
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title:
                Text(_vm.formName.isNotEmpty ? 'Edit ${_vm.formName}' : 'Edit'),
          ),
          body: _buildBody(),
        );
      },
    );
  }

  Widget _buildBody() {
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

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _vm.fields.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final df = _vm.fields[index];
              return _buildField(df);
            },
          ),
        ),
        _buildDisabledSubmitButton(),
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
      onMapPolygonPressed: f.fieldStyle == FieldStyle.mapPolygon
          ? () => _openMapForField(df)
          : null,
      resolvedOptions:
          f.fieldStyle == FieldStyle.dropdown ? df.resolvedOptions : null,
    );
  }

  /// TODO: Enable update submission once backend API is ready
  Widget _buildDisabledSubmitButton() {
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
        /// TODO: Enable update submission once backend API is ready
        onPressed: null, // Disabled — backend not ready
        icon: const Icon(Icons.cloud_upload_outlined),
        label: const Text('Update Registration'),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          disabledBackgroundColor: AppColors.light,
          disabledForegroundColor: AppColors.textMedium,
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
        _textCtrl[f.key] =
            TextEditingController(text: df.value?.toString() ?? '');
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

  void _save() {
    for (final df in _fields) {
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
                    ..._fields.map((df) => Padding(
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

    return DynamicFieldBuilder(
      field: f,
      value: _textCtrl.containsKey(f.key) ? _textCtrl[f.key]!.text : df.value,
      textController: _textCtrl[f.key],
      accentColor: AppColors.primary,
      onChanged: (val) {
        if (!_textCtrl.containsKey(f.key)) {
          setState(() => df.value = val);
        }
      },
      onPopupFormPressed: f.isPopupForm ? () => _openNestedPopupForm(df) : null,
      popupFormFilledCount: popupFormFilled,
      popupFormTotalCount: popupFormTotal,
      onMapPolygonPressed: f.fieldStyle == FieldStyle.mapPolygon
          ? () => _openMapForNested(df)
          : null,
    );
  }

  Future<void> _openMapForNested(DynamicFieldModel df) async {
    await Navigator.pushNamed(
      context,
      '/land-measurement',
      arguments: {
        'initialPolygon': df.value,
        'viewOnly': false,
      },
    );
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
