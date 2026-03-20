import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/api/api_models.dart';
import '../../models/farmer/farmer_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/form_config_service.dart';
import '../../config/app_constants.dart';
import '../../utils/app_colors.dart';
import '../../utils/snack_bar_helper.dart';
import '../../widgets/dynamic_field_builder.dart';
import '../../widgets/shimmer_loading.dart';

class FarmerFormScreen extends StatefulWidget {
  const FarmerFormScreen({super.key});

  @override
  State<FarmerFormScreen> createState() => _FarmerFormScreenState();
}

class _FarmerFormScreenState extends State<FarmerFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // ── Hardcoded controllers (location + land) ─────────────────────────────
  final _addressCtrl = TextEditingController();
  final _villageCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _landAreaCtrl = TextEditingController();

  // ── Dynamic field state ─────────────────────────────────────────────────
  final Map<String, TextEditingController> _dynTextCtrl = {};
  List<DynamicFieldModel> _dynamicFields = [];

  // ── State ───────────────────────────────────────────────────────────────
  String _selectedCategory = '';
  String _selectedSubcategory = '';
  int? _selectedSubcategoryId;
  String _selectedLandUnit = 'Acres';
  String _selectedStatus = 'Active';
  List<Map<String, double>> _landCoordinates = [];

  bool _isSaving = false;
  bool _argsProcessed = false;
  FarmerModel? _editFarmer;

  // Form config from API
  ApiForm? _form;
  bool _isLoadingForm = true;
  String? _formLoadError;

  final List<String> _landUnits = ['Acres', 'Hectares', 'Bigha', 'Sq. Meters'];

  // ── Lifecycle ───────────────────────────────────────────────────────────

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_argsProcessed) {
      _argsProcessed = true;

      final args = ModalRoute.of(context)?.settings.arguments as Map?;
      if (args != null) {
        _selectedCategory = args['category'] as String? ?? '';
        _selectedSubcategory = args['subcategory'] as String? ?? '';
        _selectedSubcategoryId = args['subcategoryId'] as int?;

        if (args['farmer'] != null) {
          _editFarmer = args['farmer'] as FarmerModel;
          _selectedCategory = _selectedCategory.isNotEmpty
              ? _selectedCategory
              : _editFarmer!.category;
          _selectedSubcategory = _selectedSubcategory.isNotEmpty
              ? _selectedSubcategory
              : _editFarmer!.subcategory;
          _selectedSubcategoryId ??= _editFarmer!.subcategoryId;
        }
      }

      // Ensure categories are loaded, then load form
      final svc = context.read<FormConfigService>();
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await svc.fetchCategories();
        if (mounted) {
          await _loadForm();
        }
      });
    }
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _villageCtrl.dispose();
    _districtCtrl.dispose();
    _stateCtrl.dispose();
    _landAreaCtrl.dispose();
    for (final c in _dynTextCtrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Form loading ────────────────────────────────────────────────────────

  Future<void> _loadForm() async {
    final svc = context.read<FormConfigService>();
    setState(() {
      _isLoadingForm = true;
      _formLoadError = null;
    });

    try {
      _selectedSubcategoryId ??= svc
          .getCategoryByName(_selectedCategory)
          ?.findSubcategory(
            _selectedSubcategory,
          )
          ?.subcategoryId;

      if (_selectedSubcategoryId != null) {
        _form = await svc.getDynamicRegistrationFields(_selectedSubcategoryId!);
      } else {
        _form = null;
      }
    } catch (error) {
      _form = null;
      _formLoadError = error.toString();
    }

    _initDynamicControllers();

    if (_editFarmer != null) {
      _populate(_editFarmer!);
    }

    if (mounted) {
      setState(() => _isLoadingForm = false);
    }
  }

  void _initDynamicControllers() {
    // Dispose old controllers
    for (final c in _dynTextCtrl.values) {
      c.dispose();
    }
    _dynTextCtrl.clear();
    _dynamicFields.clear();

    if (_form == null) return;

    for (final field in _form!.fields) {
      _dynamicFields.add(DynamicFieldModel.fromApiField(field));
      _initFieldController(field);
    }
  }

  void _initFieldController(ApiField f, {dynamic initialValue}) {
    final style = f.fieldStyle;
    if (style == FieldStyle.text ||
        style == FieldStyle.number ||
        style == FieldStyle.date) {
      _dynTextCtrl[f.key] =
          TextEditingController(text: initialValue?.toString() ?? '');
    }
  }

  void _populate(FarmerModel f) {
    // Location (hardcoded)
    _addressCtrl.text = f.address;
    _villageCtrl.text = f.village;
    _districtCtrl.text = f.district;
    _stateCtrl.text = f.state;
    _landAreaCtrl.text = f.landArea > 0 ? f.landArea.toString() : '';

    setState(() {
      _selectedCategory = f.category;
      _selectedSubcategory = f.subcategory;
      _selectedSubcategoryId = f.subcategoryId;
      _selectedLandUnit = f.landUnit;
      _selectedStatus = f.status;
      _landCoordinates = f.landCoordinates;

      // Handle form fields
      if (f.formFields.isNotEmpty) {
        _dynamicFields = f.formFields
            .map((e) =>
                DynamicFieldModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } else {
        // Map known model fields back to dynamic field keys (if they exist)
        if (f.name != null) _setDynValue('fullName', f.name!);
        if (f.phone != null) _setDynValue('mobileNumber', f.phone!);

        // Map dynamicFields legacy
        f.dynamicFields.forEach((key, value) {
          _setDynValue(key, value);
        });
      }

      // Re-init text controllers to match the correct values
      _dynTextCtrl.clear();
      for (final df in _dynamicFields) {
        _initFieldController(df.field, initialValue: df.value);
      }
    });
  }

  void _setDynValue(String key, dynamic value) {
    if (value == null) return;
    if (value is String && value.isEmpty) return;
    final idx = _dynamicFields.indexWhere((df) => df.field.key == key);
    if (idx != -1) {
      _dynamicFields[idx].value = value;
    }
  }

  // ── Land map ────────────────────────────────────────────────────────────

  Future<void> _openMap() async {
    final result = await Navigator.pushNamed(context, '/land-measurement')
        as Map<String, dynamic>?;
    if (result != null && mounted) {
      final area = result['area'] as double? ?? 0;
      final coords = result['coordinates'] as List<Map<String, double>>? ?? [];
      setState(() {
        _landCoordinates = coords;
        if (area > 0) {
          _landAreaCtrl.text = area.toStringAsFixed(4);
          _selectedLandUnit = 'Acres';
        }
      });
      context.showSnack('Area: ${area.toStringAsFixed(4)} acres',
          success: true);
    }
  }

  // ── Popup form sheet ──────────────────────────────────────────────────

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
          setState(() => df.value = result);
        },
      ),
    );
  }

  // ── Save ────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory.isEmpty) {
      context.showSnack('Select a category.');
      return;
    }
    if (_selectedSubcategory.isEmpty) {
      context.showSnack('Select a subcategory.');
      return;
    }

    setState(() => _isSaving = true);
    final auth = context.read<AuthService>();
    final fs = context.read<FirestoreService>();

    // Collect all dynamic field values for legacy structure & model properties extraction
    final Map<String, dynamic> allDynValues = {};
    for (final df in _dynamicFields) {
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
        _dynamicFields.map((e) => e.toJson()).toList();

    // Extract well-known keys for FarmerModel core fields as fallback,
    // but leave them inside the dynamic fields map
    final name = allDynValues['fullName']?.toString();
    final phone = allDynValues['mobileNumber']?.toString();

    final farmer = FarmerModel(
      id: _editFarmer?.id,
      name: name,
      phone: phone,
      address: _addressCtrl.text.trim(),
      village: _villageCtrl.text.trim(),
      district: _districtCtrl.text.trim(),
      state: _stateCtrl.text.trim(),
      category: _selectedCategory,
      subcategory: _selectedSubcategory,
      subcategoryId: _selectedSubcategoryId,
      landArea: double.tryParse(_landAreaCtrl.text) ?? 0,
      landUnit: _selectedLandUnit,
      landCoordinates: _landCoordinates,
      dynamicFields: allDynValues,
      formFields: serializedFields,
      status: _selectedStatus,
      userId: auth.userId, // Use locally stored User ID
    );

    // Print clean backend-ready payload structure for debugging
    final submissionPayload = <String, dynamic>{
      'registrationData': <String, dynamic>{
        'subcategoryId': _selectedSubcategoryId ?? 0,
        'registrationDate': farmer.registrationDate.toIso8601String(),
        'status': _selectedStatus,
        'userId': auth.userId,
        // 'geoLocation': <String, dynamic>{
        //   'areaInput': _landAreaCtrl.text.trim(),
        //   'areaParsed': double.tryParse(_landAreaCtrl.text) ?? 0,
        //   'landUnit': _selectedLandUnit,
        //   'landCoordinates': _landCoordinates,
        // },
        // 'userLocation': <String, dynamic>{
        //   'address': _addressCtrl.text.trim(),
        //   'village': _villageCtrl.text.trim(),
        //   'district': _districtCtrl.text.trim(),
        //   'state': _stateCtrl.text.trim(),
        // },
        'fields': serializedFields,
      },
    };
    final prettyJson =
        const JsonEncoder.withIndent('  ').convert(submissionPayload);
    debugPrint('=== SUBMITTING FARMER REGISTRATION ===');
    debugPrint(prettyJson);
    debugPrint('======================================');

    try {
      if (_editFarmer != null) {
        await fs.updateFarmer(farmer);
        debugPrint(
            '=== FARMER REGISTRATION RESULT === action=update_farmer id=${farmer.id} success=true');
        if (mounted) context.showSnack('Updated successfully!', success: true);
      } else {
        final createdId = await fs.addFarmer(farmer);
        debugPrint(
            '=== FARMER REGISTRATION RESULT === action=create_farmer id=$createdId success=true');
        if (mounted) context.showSnack('Farmer registered!', success: true);
      }
      if (mounted) {
        if (_editFarmer != null) {
          Navigator.pop(context);
        } else {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/dashboard',
            (route) => false,
          );
        }
      }
    } catch (e) {
      debugPrint(
          '=== FARMER REGISTRATION RESULT === success=false error=${e.toString()}');
      if (mounted) context.showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final catData = AppCategories.styleFor(_selectedCategory);
    final catColor = catData?.color ?? AppColors.primary;
    final geoRequired = _form?.geoLocationRequired ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(
            _editFarmer != null ? 'Edit Registration' : 'New Registration'),
        actions: [
          _isSaving
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    ),
                  ),
                )
              : TextButton.icon(
                  onPressed: _isLoadingForm ? null : _save,
                  icon: const Icon(Icons.save, color: Colors.white),
                  label: const Text('Save',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ),
        ],
      ),
      body: _isLoadingForm
          ? const ShimmerFormSkeleton()
          : _formLoadError != null && _dynamicFields.isEmpty
              ? _FormLoadErrorState(
                  message: _formLoadError!,
                  onRetry: _loadForm,
                )
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // ── Category / Subcategory badge ────────────────────────
                      if (_selectedCategory.isNotEmpty) ...[
                        _buildCategoryBadge(catColor, catData),
                        const SizedBox(height: 20),
                      ],

                      // ── Dynamic fields from API ────────────────────────────
                      ..._buildDynamicFields(catColor),

                      // ── Location (hardcoded) ───────────────────────────────
                      const SizedBox(height: 20),
                      ..._buildLocationSection(),

                      // ── Land Details (conditional) ─────────────────────────
                      if (geoRequired) ...[
                        const SizedBox(height: 24),
                        _Section(
                            title: 'Land Details',
                            icon: Icons.landscape_outlined),
                        const SizedBox(height: 12),
                        ..._buildLandSection(),
                      ],



                      // ── Submit ─────────────────────────────────────────────
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _save,
                          icon: const Icon(Icons.how_to_reg),
                          label: Text(_editFarmer != null
                              ? 'Update Registration'
                              : 'Complete Registration'),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  // ── Category badge ──────────────────────────────────────────────────────

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
                  _selectedCategory,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: catColor,
                  ),
                ),
                if (_selectedSubcategory.isNotEmpty)
                  Text(
                    _selectedSubcategory,
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

  // ── Dynamic fields ──────────────────────────────────────────────────────

  List<Widget> _buildDynamicFields(Color catColor) {
    if (_dynamicFields.isEmpty) return [];
    return _dynamicFields
        .map((df) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildDynamicField(df, catColor),
            ))
        .toList();
  }

  Widget _buildDynamicField(DynamicFieldModel df, Color catColor) {
    final f = df.field;
    // For POPUP-FORM, compute filled count
    int? popupFormFilled;
    int? popupFormTotal;
    if (f.isPopupForm) {
      final subFieldsList = df.value as List<DynamicFieldModel>? ?? [];
      popupFormTotal = subFieldsList.length;
      popupFormFilled =
          subFieldsList.where((e) => e.value != null && e.value != '').length;
    }

    return DynamicFieldBuilder(
      field: f,
      value: df.value,
      textController: _dynTextCtrl[f.key],
      accentColor: catColor,
      onChanged: (val) {
        setState(() => df.value = val);
      },
      onPopupFormPressed:
          f.isPopupForm ? () => _openPopupFormSheet(df, catColor) : null,
      popupFormFilledCount: popupFormFilled,
      popupFormTotalCount: popupFormTotal,
    );
  }

  // ── Location section (hardcoded) ────────────────────────────────────────

  List<Widget> _buildLocationSection() {
    return [
      TextFormField(
        controller: _addressCtrl,
        decoration: const InputDecoration(
          labelText: 'Full Address *',
          prefixIcon: Icon(Icons.location_on_outlined),
        ),
        maxLines: 2,
        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: TextFormField(
            controller: _villageCtrl,
            decoration: const InputDecoration(
              labelText: 'Village / Town',
              prefixIcon: Icon(Icons.house_outlined),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            controller: _districtCtrl,
            decoration: const InputDecoration(
              labelText: 'District',
              prefixIcon: Icon(Icons.map_outlined),
            ),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      TextFormField(
        controller: _stateCtrl,
        decoration: const InputDecoration(
          labelText: 'State',
          prefixIcon: Icon(Icons.flag_outlined),
        ),
      ),
    ];
  }

  // ── Land section (hardcoded, conditional) ───────────────────────────────

  List<Widget> _buildLandSection() {
    return [
      OutlinedButton.icon(
        onPressed: _openMap,
        icon: const Icon(Icons.map),
        label: Text(_landCoordinates.isEmpty
            ? 'Measure Land on Map'
            : 'Re-measure  (${_landCoordinates.length} pts)'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
        ),
      ),
      const SizedBox(height: 12),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          flex: 3,
          child: TextFormField(
            controller: _landAreaCtrl,
            decoration: const InputDecoration(
              labelText: 'Land Area *',
              prefixIcon: Icon(Icons.square_foot_outlined),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
            initialValue: _selectedLandUnit,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Unit'),
            items: _landUnits
                .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                .toList(),
            onChanged: (v) => setState(() => _selectedLandUnit = v!),
          ),
        ),
      ]),
    ];
  }


}

class _FormLoadErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _FormLoadErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 40,
              color: AppColors.textMedium,
            ),
            const SizedBox(height: 12),
            const Text(
              'Unable to load registration fields',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.dark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(color: AppColors.textMedium),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
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
  const _Section({
    required this.title,
    required this.icon,
  });

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

  const _PopupFormSheet({
    required this.parentField,
    required this.catColor,
    required this.initialFields,
    required this.onSaved,
  });

  @override
  State<_PopupFormSheet> createState() => _PopupFormSheetState();
}

class _PopupFormSheetState extends State<_PopupFormSheet> {
  final Map<String, TextEditingController> _textCtrl = {};
  late List<DynamicFieldModel> _fields;

  @override
  void initState() {
    super.initState();
    _fields = widget.initialFields.map((e) => e.copyWith()).toList();

    for (final df in _fields) {
      final f = df.field;
      final init = df.value;
      if (f.fieldStyle == FieldStyle.text ||
          f.fieldStyle == FieldStyle.number ||
          f.fieldStyle == FieldStyle.date) {
        _textCtrl[f.key] = TextEditingController(text: init?.toString() ?? '');
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
    final color = widget.catColor;
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
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title row
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
                    icon: const Icon(Icons.close, color: AppColors.textMedium),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Sub-form fields
            Expanded(
              child: SingleChildScrollView(
                controller: ctrl,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    ..._fields.map((df) => Padding(
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
                          backgroundColor: color,
                        ),
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

  Widget _buildSubField(DynamicFieldModel df, Color color) {
    final f = df.field;
    // Compute popup-form filled count for nested sub-forms
    int? popupFormFilled;
    int? popupFormTotal;
    if (f.isPopupForm) {
      final subFieldsList = df.value as List<DynamicFieldModel>? ?? [];
      popupFormTotal = subFieldsList.length;
      popupFormFilled =
          subFieldsList.where((e) => e.value != null && e.value != '').length;
    }

    return DynamicFieldBuilder(
      field: f,
      value: _textCtrl.containsKey(f.key) ? _textCtrl[f.key]!.text : df.value,
      textController: _textCtrl[f.key],
      accentColor: color,
      onChanged: (val) {
        if (!_textCtrl.containsKey(f.key)) {
          setState(() => df.value = val);
        }
      },
      onPopupFormPressed:
          f.isPopupForm ? () => _openNestedPopupForm(df, color) : null,
      popupFormFilledCount: popupFormFilled,
      popupFormTotalCount: popupFormTotal,
    );
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
        },
      ),
    );
  }
}
