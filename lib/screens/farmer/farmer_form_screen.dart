import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/api/api_models.dart';
import '../../models/farmer/farmer_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/form_config_service.dart';
import '../../services/location_service.dart';
import '../../config/app_constants.dart';
import '../../utils/app_colors.dart';
import '../../widgets/dynamic_field_builder.dart';
import '../../widgets/shimmer_loading.dart';

class FarmerFormScreen extends StatefulWidget {
  const FarmerFormScreen({super.key});

  @override
  State<FarmerFormScreen> createState() => _FarmerFormScreenState();
}

class _FarmerFormScreenState extends State<FarmerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _locationService = LocationService();

  // ── Hardcoded controllers (location + land) ─────────────────────────────
  final _addressCtrl = TextEditingController();
  final _villageCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _landAreaCtrl = TextEditingController();

  // ── Dynamic field state ─────────────────────────────────────────────────
  final Map<String, TextEditingController> _dynTextCtrl = {};
  final Map<String, dynamic> _dynValues = {};

  // ── State ───────────────────────────────────────────────────────────────
  String _selectedCategory = '';
  String _selectedSubcategory = '';
  int? _selectedSubcategoryId;
  String _selectedLandUnit = 'Acres';
  String _selectedStatus = 'Active';
  List<Map<String, double>> _landCoordinates = [];
  double? _latitude;
  double? _longitude;

  bool _isSaving = false;
  bool _isLocating = false;
  bool _argsProcessed = false;
  FarmerModel? _editFarmer;

  // Form config from API
  ApiForm? _form;
  bool _isLoadingForm = true;

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
        }
      }

      // Ensure categories are loaded, then load form
      final svc = context.read<FormConfigService>();
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await svc.fetchCategories();
        if (mounted) _loadForm();
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

  void _loadForm() {
    final svc = context.read<FormConfigService>();
    final form = svc.getForm(_selectedCategory, _selectedSubcategory);

    if (form == null) {
      // Fallback: try to get any form for the category
      final cat = svc.getCategoryByName(_selectedCategory);
      final sub = cat?.subcategories.isNotEmpty == true
          ? cat!.subcategories.first
          : null;
      _form = sub?.primaryForm;
    } else {
      _form = form;
    }

    _initDynamicControllers();

    if (_editFarmer != null) {
      _populate(_editFarmer!);
    }

    setState(() => _isLoadingForm = false);
  }

  void _initDynamicControllers() {
    // Dispose old controllers
    for (final c in _dynTextCtrl.values) {
      c.dispose();
    }
    _dynTextCtrl.clear();
    _dynValues.clear();

    if (_form == null) return;

    for (final field in _form!.fields) {
      _initFieldController(field);
      // Also init popup sub-fields
      if (field.fieldStyle == FieldStyle.button && field.popup != null) {
        for (final pf in field.popup!.fields) {
          _initFieldController(pf);
        }
      }
    }
  }

  void _initFieldController(ApiField f) {
    final style = f.fieldStyle;
    if (style == FieldStyle.text || style == FieldStyle.date) {
      _dynTextCtrl[f.key] = TextEditingController();
    } else if (style == FieldStyle.dropdown) {
      _dynValues[f.key] = null;
    } else if (style == FieldStyle.checkbox) {
      _dynValues[f.key] = false;
    } else if (style == FieldStyle.radio) {
      _dynValues[f.key] = null;
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
      _latitude = f.latitude;
      _longitude = f.longitude;

      // Map known model fields back to dynamic field keys
      _setDynValue('full_name', f.name);
      _setDynValue('mobile_number', f.phone);

      // Map dynamicFields
      f.dynamicFields.forEach((key, value) {
        _setDynValue(key, value);
      });
    });
  }

  void _setDynValue(String key, String value) {
    if (value.isEmpty) return;
    if (_dynTextCtrl.containsKey(key)) {
      _dynTextCtrl[key]!.text = value;
    } else {
      _dynValues[key] = value;
    }
  }

  // ── Geolocation ─────────────────────────────────────────────────────────

  Future<void> _detectLocation() async {
    if (_isLocating) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLocating = true);

    try {
      final pos = await _locationService.getCurrentPosition();

      if (mounted) {
        setState(() {
          _latitude = pos.latitude;
          _longitude = pos.longitude;
        });
      }

      try {
        final result =
            await _locationService.reverseGeocode(pos.latitude, pos.longitude);
        if (!mounted) {
          return;
        }

        setState(() {
          if (result.address.isNotEmpty) _addressCtrl.text = result.address;
          if (result.village.isNotEmpty) _villageCtrl.text = result.village;
          if (result.district.isNotEmpty) _districtCtrl.text = result.district;
          if (result.state.isNotEmpty) _stateCtrl.text = result.state;
        });
        _snack('Location auto-filled', success: true);
      } on LocationException catch (e) {
        _snack(
          'GPS detected. Address lookup timed out/failed: ${e.message}',
          success: true,
        );
      } catch (_) {
        _snack('GPS detected. Could not auto-fill address.');
      }
    } on LocationException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Failed to detect location. Please try again.');
    } finally {
      if (mounted) setState(() => _isLocating = false);
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
      _snack('Area: ${area.toStringAsFixed(4)} acres', success: true);
    }
  }

  // ── Popup sheet ─────────────────────────────────────────────────────────

  void _openPopupSheet(ApiPopup popup, Color catColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PopupFieldSheet(
        popup: popup,
        catColor: catColor,
        textCtrl: _dynTextCtrl,
        dynValues: _dynValues,
        onSaved: (updated) {
          setState(() {
            updated.forEach((k, v) => _dynValues[k] = v);
          });
        },
      ),
    );
  }

  // ── Save ────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory.isEmpty) {
      _snack('Select a category.');
      return;
    }
    if (_selectedSubcategory.isEmpty) {
      _snack('Select a subcategory.');
      return;
    }

    setState(() => _isSaving = true);
    final auth = context.read<AuthService>();
    final fs = context.read<FirestoreService>();

    // Collect all dynamic field values
    final Map<String, String> allDynValues = {};
    _dynTextCtrl.forEach((k, c) {
      if (c.text.isNotEmpty) allDynValues[k] = c.text.trim();
    });
    _dynValues.forEach((k, v) {
      if (v != null && v.toString().isNotEmpty) {
        allDynValues[k] = v.toString();
      }
    });

    // Extract well-known keys for FarmerModel core fields
    final name = allDynValues.remove('full_name') ?? '';
    final phone = allDynValues.remove('mobile_number') ?? '';

    final farmer = FarmerModel(
      id: _editFarmer?.id,
      name: name,
      phone: phone,
      address: _addressCtrl.text.trim(),
      village: _villageCtrl.text.trim(),
      district: _districtCtrl.text.trim(),
      state: _stateCtrl.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
      category: _selectedCategory,
      subcategory: _selectedSubcategory,
      subcategoryId: _selectedSubcategoryId,
      landArea: double.tryParse(_landAreaCtrl.text) ?? 0,
      landUnit: _selectedLandUnit,
      landCoordinates: _landCoordinates,
      dynamicFields: allDynValues,
      status: _selectedStatus,
      registeredBy: auth.userId, // Use locally stored User ID
    );

    try {
      if (_editFarmer != null) {
        await fs.updateFarmer(farmer);
        _snack('Updated successfully!', success: true);
      } else {
        await fs.addFarmer(farmer);
        _snack('Farmer registered!', success: true);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _snack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? AppColors.primary : AppColors.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final catData = AppCategories.all[_selectedCategory];
    final catColor = catData?.color ?? AppColors.primary;
    final geoRequired = _form?.formConfig.geoLocationRequired ?? false;

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

                  // ── Dynamic sections from API ──────────────────────────
                  ..._buildDynamicSections(catColor),

                  // ── Location (hardcoded) ───────────────────────────────
                  const SizedBox(height: 20),
                  _Section(title: 'Location', icon: Icons.location_on_outlined),
                  const SizedBox(height: 12),
                  ..._buildLocationSection(),

                  // ── Land Details (conditional) ─────────────────────────
                  if (geoRequired) ...[
                    const SizedBox(height: 24),
                    _Section(
                        title: 'Land Details', icon: Icons.landscape_outlined),
                    const SizedBox(height: 12),
                    ..._buildLandSection(),
                  ],

                  // ── Status (hardcoded) ─────────────────────────────────
                  const SizedBox(height: 24),
                  _Section(title: 'Status', icon: Icons.toggle_on_outlined),
                  const SizedBox(height: 12),
                  _buildStatusSection(),

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

  // ── Dynamic sections ────────────────────────────────────────────────────

  List<Widget> _buildDynamicSections(Color catColor) {
    if (_form == null) return [];
    final sections = _form!.sections;
    if (sections.isEmpty) {
      // Fallback: render flat fields without section headers
      return _form!.fields
          .map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildDynamicField(f, catColor),
              ))
          .toList();
    }

    final widgets = <Widget>[];
    for (int i = 0; i < sections.length; i++) {
      final section = sections[i];
      if (i > 0) widgets.add(const SizedBox(height: 24));

      // Section header
      widgets.add(_Section(
        title: section.sectionTitle.isNotEmpty
            ? section.sectionTitle
            : 'Section ${i + 1}',
        icon: _sectionIcon(section.sectionId),
        color: catColor,
      ));
      widgets.add(const SizedBox(height: 12));

      // Section fields
      for (final field in section.fields) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildDynamicField(field, catColor),
        ));
      }
    }
    return widgets;
  }

  IconData _sectionIcon(String sectionId) {
    if (sectionId.contains('personal')) return Icons.person_outline;
    return Icons.info_outline;
  }

  Widget _buildDynamicField(ApiField f, Color catColor) {
    // For BUTTON type, compute popup filled count
    int? popupFilled;
    int? popupTotal;
    if (f.fieldStyle == FieldStyle.button && f.popup != null) {
      final popup = f.popup!;
      popupTotal = popup.fields.length;
      popupFilled = popup.fields.where((pf) {
        if (_dynTextCtrl.containsKey(pf.key)) {
          return (_dynTextCtrl[pf.key]?.text ?? '').isNotEmpty;
        }
        final val = _dynValues[pf.key];
        return val != null && val.toString().isNotEmpty;
      }).length;
    }

    return DynamicFieldBuilder(
      field: f,
      value: _dynTextCtrl.containsKey(f.key)
          ? _dynTextCtrl[f.key]!.text
          : _dynValues[f.key],
      textController: _dynTextCtrl[f.key],
      accentColor: catColor,
      onChanged: (val) {
        if (!_dynTextCtrl.containsKey(f.key)) {
          setState(() => _dynValues[f.key] = val);
        }
      },
      onPopupPressed: f.fieldStyle == FieldStyle.button && f.popup != null
          ? () => _openPopupSheet(f.popup!, catColor)
          : null,
      popupFilledCount: popupFilled,
      popupTotalCount: popupTotal,
    );
  }

  // ── Location section (hardcoded) ────────────────────────────────────────

  List<Widget> _buildLocationSection() {
    return [
      OutlinedButton.icon(
        onPressed: _isLocating ? null : _detectLocation,
        icon: _isLocating
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.my_location),
        label: Text(_isLocating
            ? 'Detecting...'
            : _latitude != null
                ? 'GPS: ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}'
                : 'Auto-detect My Location'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          foregroundColor:
              _latitude != null ? AppColors.primary : AppColors.textMedium,
          side: BorderSide(
            color: _latitude != null ? AppColors.primary : AppColors.light,
          ),
        ),
      ),
      const SizedBox(height: 12),
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

  // ── Status section (hardcoded) ──────────────────────────────────────────

  Widget _buildStatusSection() {
    return Row(
      children: ['Active', 'Inactive'].map((s) {
        final sel = _selectedStatus == s;
        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: FilterChip(
            label: Text(s),
            selected: sel,
            onSelected: (_) => setState(() => _selectedStatus = s),
            selectedColor: AppColors.light,
            checkmarkColor: AppColors.dark,
            labelStyle: TextStyle(
              color: sel ? AppColors.dark : AppColors.textMedium,
              fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────
class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  const _Section({
    required this.title,
    required this.icon,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: 8),
      Text(title,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color == AppColors.primary ? AppColors.dark : color)),
      const SizedBox(width: 8),
      Expanded(
          child: Divider(color: color.withValues(alpha: 0.35), thickness: 1.5)),
    ]);
  }
}

// ─── Popup Field Sheet ────────────────────────────────────────────────────────
class _PopupFieldSheet extends StatefulWidget {
  final ApiPopup popup;
  final Color catColor;
  final Map<String, TextEditingController> textCtrl;
  final Map<String, dynamic> dynValues;
  final void Function(Map<String, dynamic> updated) onSaved;

  const _PopupFieldSheet({
    required this.popup,
    required this.catColor,
    required this.textCtrl,
    required this.dynValues,
    required this.onSaved,
  });

  @override
  State<_PopupFieldSheet> createState() => _PopupFieldSheetState();
}

class _PopupFieldSheetState extends State<_PopupFieldSheet> {
  late Map<String, dynamic> _localValues;

  @override
  void initState() {
    super.initState();
    _localValues = {
      for (final f in widget.popup.fields)
        if (f.fieldStyle == FieldStyle.dropdown ||
            f.fieldStyle == FieldStyle.radio)
          f.key: widget.dynValues[f.key] ?? '',
    };
  }

  void _save() {
    widget.onSaved(_localValues);
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
                      widget.popup.title,
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
            // Fields
            Expanded(
              child: SingleChildScrollView(
                controller: ctrl,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    ...widget.popup.fields.map((f) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _buildPopupField(f, color),
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

  Widget _buildPopupField(ApiField f, Color color) {
    switch (f.fieldStyle) {
      case FieldStyle.text:
        return TextFormField(
          controller: widget.textCtrl[f.key],
          decoration: InputDecoration(
            labelText: f.label,
            prefixIcon: Icon(
              f.fieldType == FieldType.number
                  ? Icons.numbers_outlined
                  : Icons.edit_note_outlined,
              color: color,
            ),
          ),
          textCapitalization: f.fieldType == FieldType.number
              ? TextCapitalization.none
              : TextCapitalization.sentences,
          keyboardType: f.fieldType == FieldType.number
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          inputFormatters: [
            if (f.fieldType == FieldType.number)
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
          ],
        );

      case FieldStyle.dropdown:
        return DropdownButtonFormField<String>(
          initialValue: (_localValues[f.key]?.toString().isEmpty ?? true)
              ? null
              : _localValues[f.key] as String?,
          decoration: InputDecoration(
            labelText: f.label,
            prefixIcon:
                Icon(Icons.arrow_drop_down_circle_outlined, color: color),
          ),
          hint: Text('Select ${f.label}'),
          items: f.fieldData
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          onChanged: (v) => setState(() => _localValues[f.key] = v ?? ''),
        );

      default:
        return const SizedBox.shrink();
    }
  }
}
