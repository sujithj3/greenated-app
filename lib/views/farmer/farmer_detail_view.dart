import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/api/api_models.dart';
import '../../services/auth_service.dart';
import '../../services/registration_form_service.dart';
import '../../utils/app_colors.dart';
import '../../view_models/farmer/farmer_detail_view_model.dart';
import '../../widgets/dynamic_field_builder.dart';
import '../../widgets/shimmer_loading.dart';

class FarmerDetailView extends StatefulWidget {
  final int subcategoryId;
  final int submissionId;

  const FarmerDetailView({
    super.key,
    required this.subcategoryId,
    required this.submissionId,
  });

  @override
  State<FarmerDetailView> createState() => _FarmerDetailViewState();
}

class _FarmerDetailViewState extends State<FarmerDetailView> {
  late final FarmerDetailViewModel _vm;
  final Map<String, TextEditingController> _textCtrl = {};
  bool _isInit = false;

  @override
  void initState() {
    super.initState();
    _vm = FarmerDetailViewModel(
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
        await _vm.loadFormDetail(
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

  Future<void> _openViewOnlyPopupSheet(DynamicFieldModel df) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ViewOnlyPopupSheet(
        parentField: df.field,
        fields: df.value as List<DynamicFieldModel>? ?? [],
      ),
    );
  }

  Future<void> _openViewOnlyMap(DynamicFieldModel df) async {
    await Navigator.pushNamed(
      context,
      '/land-measurement',
      arguments: {
        'initialPolygon': df.value,
        'viewOnly': true,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(_vm.formName.isNotEmpty ? _vm.formName : 'Detail'),
            actions: [
              TextButton.icon(
                onPressed: () async {
                  final result = await Navigator.pushNamed(
                    context,
                    '/edit-farmer-details',
                    arguments: {
                      'subcategoryId': widget.subcategoryId,
                      'submissionId': widget.submissionId,
                    },
                  );

                  if (result == true && context.mounted) {
                    // Small delay to allow iOS CupertinoPageRoute pop animation to complete
                    Future.delayed(const Duration(milliseconds: 400), () {
                      if (context.mounted) {
                        Navigator.pop(context, true);
                      }
                    });
                  }
                },
                icon: const Icon(Icons.edit, size: 18, color: AppColors.white),
                label: const Text(
                  'Edit',
                  style: TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
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
                'Unable to load form detail',
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
                onPressed: () => _vm.loadFormDetail(
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

    final visibleFields = _vm.fields
        .where((df) => shouldShowField(df, _vm.fields))
        .toList();

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: visibleFields.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildField(visibleFields[index]),
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

    final isCameraField =
        f.fieldStyle == FieldStyle.camera || f.fieldStyle == FieldStyle.cameraFile;

    return DynamicFieldBuilder(
      field: f,
      value: _textCtrl.containsKey(f.key) ? _textCtrl[f.key]!.text : df.value,
      textController: _textCtrl[f.key],
      accentColor: AppColors.primary,
      onChanged: (_) {},
      isViewMode: true,
      onPopupFormPressed:
          f.isPopupForm ? () => _openViewOnlyPopupSheet(df) : null,
      popupFormFilledCount: popupFormFilled,
      popupFormTotalCount: popupFormTotal,
      onMapPolygonPressed: f.fieldStyle == FieldStyle.mapPolygon
          ? () => _openViewOnlyMap(df)
          : null,
      resolvedOptions:
          f.fieldStyle == FieldStyle.dropdown ? df.resolvedOptions : null,
      previewUrl: isCameraField ? df.previewUrl : null,
    );
  }
}

// ─── View-Only Popup Sheet ────────────────────────────────────────────────────

class _ViewOnlyPopupSheet extends StatefulWidget {
  final ApiField parentField;
  final List<DynamicFieldModel> fields;

  const _ViewOnlyPopupSheet({
    required this.parentField,
    required this.fields,
  });

  @override
  State<_ViewOnlyPopupSheet> createState() => _ViewOnlyPopupSheetState();
}

class _ViewOnlyPopupSheetState extends State<_ViewOnlyPopupSheet> {
  final Map<String, TextEditingController> _textCtrl = {};

  @override
  void initState() {
    super.initState();
    for (final df in widget.fields) {
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

  Future<void> _openNestedPopup(DynamicFieldModel df) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ViewOnlyPopupSheet(
        parentField: df.field,
        fields: df.value as List<DynamicFieldModel>? ?? [],
      ),
    );
  }

  Future<void> _openViewOnlyMap(DynamicFieldModel df) async {
    await Navigator.pushNamed(
      context,
      '/land-measurement',
      arguments: {
        'initialPolygon': df.value,
        'viewOnly': true,
      },
    );
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
                  const Icon(Icons.visibility_outlined,
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
                  children: widget.fields
                      .where((df) => shouldShowField(df, widget.fields))
                      .map((df) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _buildSubField(df),
                          ))
                      .toList(),
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
      onChanged: (_) {},
      isViewMode: true,
      onPopupFormPressed: f.isPopupForm ? () => _openNestedPopup(df) : null,
      popupFormFilledCount: popupFormFilled,
      popupFormTotalCount: popupFormTotal,
      onMapPolygonPressed: f.fieldStyle == FieldStyle.mapPolygon
          ? () => _openViewOnlyMap(df)
          : null,
      resolvedOptions:
          f.fieldStyle == FieldStyle.dropdown ? df.resolvedOptions : null,
      previewUrl: isCameraField ? df.previewUrl : null,
    );
  }
}
