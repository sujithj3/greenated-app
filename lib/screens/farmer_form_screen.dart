import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../models/api_models.dart';
import '../models/farmer_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/form_config_service.dart';
import '../utils/app_colors.dart';
import '../utils/demo_data.dart';

const String _mapsApiKey = 'AIzaSyCxU7C748sONe0a696gWBHrs_iCcF3dVkk';

class FarmerFormScreen extends StatefulWidget {
  const FarmerFormScreen({super.key});

  @override
  State<FarmerFormScreen> createState() => _FarmerFormScreenState();
}

class _FarmerFormScreenState extends State<FarmerFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // ── Core controllers ──────────────────────────────────────────────────────
  final _nameCtrl     = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _addressCtrl  = TextEditingController();
  final _villageCtrl  = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _stateCtrl    = TextEditingController();
  final _landAreaCtrl = TextEditingController();

  // ── State ─────────────────────────────────────────────────────────────────
  String _selectedCategory    = '';
  String _selectedSubcategory = '';
  String _selectedLandUnit    = 'Acres';
  String _selectedStatus      = 'Active';
  List<Map<String, double>> _landCoordinates = [];
  double? _latitude;
  double? _longitude;

  // Dynamic field state (keyed by ApiField.key, includes popup sub-fields)
  final Map<String, TextEditingController> _dynTextCtrl = {};
  final Map<String, String> _dynDropdown = {};

  bool _isSaving   = false;
  bool _isLocating = false;
  bool _configFetched = false;
  FarmerModel? _editFarmer;

  final List<String> _landUnits = ['Acres', 'Hectares', 'Bigha', 'Sq. Meters'];

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Kick off fetch once
    if (!_configFetched) {
      _configFetched = true;
      context.read<FormConfigService>().fetchCategories();
    }

    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    if (args != null) {
      if (args['category'] != null && _selectedCategory.isEmpty) {
        _setCategory(args['category'] as String);
      }
      if (args['farmer'] != null && _editFarmer == null) {
        _editFarmer = args['farmer'] as FarmerModel;
        _populate(_editFarmer!);
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _phoneCtrl.dispose(); _addressCtrl.dispose();
    _villageCtrl.dispose(); _districtCtrl.dispose(); _stateCtrl.dispose();
    _landAreaCtrl.dispose();
    for (final c in _dynTextCtrl.values) c.dispose();
    super.dispose();
  }

  // ── Category helpers ──────────────────────────────────────────────────────

  void _setCategory(String cat) {
    _selectedCategory    = cat;
    _selectedSubcategory = '';
    _rebuildDynControllers(cat);
  }

  /// Returns the template ApiField list for a category
  /// (all subcategories share the same form fields).
  List<ApiField> _fieldsForCategory(String category) {
    final svc = context.read<FormConfigService>();
    final cat = svc.getCategoryByName(category);
    if (cat == null || cat.subcategories.isEmpty) return [];
    return cat.subcategories.first.primaryForm?.fields ?? [];
  }

  void _rebuildDynControllers(String category) {
    for (final c in _dynTextCtrl.values) c.dispose();
    _dynTextCtrl.clear();
    _dynDropdown.clear();

    for (final f in _fieldsForCategory(category)) {
      _initField(f);
      // Also initialise nested popup fields
      if (f.type == 'BUTTON' && f.popup != null) {
        for (final pf in f.popup!.fields) {
          _initField(pf);
        }
      }
    }
  }

  void _initField(ApiField f) {
    if (f.type == 'DROPDOWN') {
      _dynDropdown[f.key] = '';
    } else if (f.type == 'TEXT' || f.type == 'NUMBER') {
      _dynTextCtrl[f.key] = TextEditingController();
    }
  }

  void _populate(FarmerModel f) {
    _nameCtrl.text     = f.name;
    _phoneCtrl.text    = f.phone;
    _addressCtrl.text  = f.address;
    _villageCtrl.text  = f.village;
    _districtCtrl.text = f.district;
    _stateCtrl.text    = f.state;
    _landAreaCtrl.text = f.landArea > 0 ? f.landArea.toString() : '';
    setState(() {
      _selectedCategory    = f.category;
      _selectedSubcategory = f.subcategory;
      _selectedLandUnit    = f.landUnit;
      _selectedStatus      = f.status;
      _landCoordinates     = f.landCoordinates;
      _latitude            = f.latitude;
      _longitude           = f.longitude;
      _rebuildDynControllers(f.category);
      f.dynamicFields.forEach((key, value) {
        if (_dynTextCtrl.containsKey(key)) {
          _dynTextCtrl[key]!.text = value;
        } else if (_dynDropdown.containsKey(key)) {
          _dynDropdown[key] = value;
        }
      });
    });
  }

  // ── Geolocation ───────────────────────────────────────────────────────────

  Future<void> _detectLocation() async {
    if (kDemoMode) {
      setState(() {
        _latitude  = 26.8467;
        _longitude = 80.9462;
        _addressCtrl.text  = 'Near Panchayat Bhavan, Village Road';
        _villageCtrl.text  = 'Sundarpur';
        _districtCtrl.text = 'Lucknow';
        _stateCtrl.text    = 'Uttar Pradesh';
      });
      _snack('Demo location detected ✓', success: true);
      return;
    }

    setState(() => _isLocating = true);
    try {
      bool enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) { _snack('Please enable location services.'); return; }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _snack('Location permission denied.');
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() { _latitude = pos.latitude; _longitude = pos.longitude; });
      await _reverseGeocode(pos.latitude, pos.longitude);
    } catch (e) {
      _snack('Location error: $e');
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?latlng=$lat,$lng&key=$_mapsApiKey',
      );
      final res = await http.get(uri);
      if (res.statusCode != 200) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') return;
      final comps = (data['results'] as List).first['address_components'] as List;
      String village = '', district = '', state = '';
      for (final c in comps) {
        final types = List<String>.from(c['types'] as List);
        final name  = c['long_name'] as String;
        if (types.contains('sublocality') || types.contains('locality')) village  = name;
        if (types.contains('administrative_area_level_2'))                district = name;
        if (types.contains('administrative_area_level_1'))                state    = name;
      }
      setState(() {
        _addressCtrl.text  = (data['results'] as List).first['formatted_address'] ?? '';
        if (village.isNotEmpty)  _villageCtrl.text  = village;
        if (district.isNotEmpty) _districtCtrl.text = district;
        if (state.isNotEmpty)    _stateCtrl.text    = state;
      });
      _snack('Location auto-filled ✓', success: true);
    } catch (_) {}
  }

  // ── Category sheet ────────────────────────────────────────────────────────

  void _openCategorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CategorySheet(
        onSelected: (cat) {
          Navigator.pop(context);
          setState(() => _setCategory(cat));
        },
      ),
    );
  }

  // ── Land map ──────────────────────────────────────────────────────────────

  Future<void> _openMap() async {
    final result =
        await Navigator.pushNamed(context, '/land-measurement')
            as Map<String, dynamic>?;
    if (result != null && mounted) {
      final area   = result['area'] as double? ?? 0;
      final coords = result['coordinates'] as List<Map<String, double>>? ?? [];
      setState(() {
        _landCoordinates = coords;
        if (area > 0) {
          _landAreaCtrl.text = area.toStringAsFixed(4);
          _selectedLandUnit  = 'Acres';
        }
      });
      _snack('Area: ${area.toStringAsFixed(4)} acres', success: true);
    }
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory.isEmpty)    { _snack('Select a category.');    return; }
    if (_selectedSubcategory.isEmpty) { _snack('Select a subcategory.'); return; }

    setState(() => _isSaving = true);
    final auth = context.read<AuthService>();
    final fs   = context.read<FirestoreService>();

    final Map<String, String> dynValues = {};
    _dynTextCtrl.forEach((k, c) { if (c.text.isNotEmpty) dynValues[k] = c.text.trim(); });
    _dynDropdown.forEach((k, v) { if (v.isNotEmpty) dynValues[k] = v; });

    final farmer = FarmerModel(
      id:              _editFarmer?.id,
      name:            _nameCtrl.text.trim(),
      phone:           _phoneCtrl.text.trim(),
      address:         _addressCtrl.text.trim(),
      village:         _villageCtrl.text.trim(),
      district:        _districtCtrl.text.trim(),
      state:           _stateCtrl.text.trim(),
      latitude:        _latitude,
      longitude:       _longitude,
      category:        _selectedCategory,
      subcategory:     _selectedSubcategory,
      landArea:        double.tryParse(_landAreaCtrl.text) ?? 0,
      landUnit:        _selectedLandUnit,
      landCoordinates: _landCoordinates,
      dynamicFields:   dynValues,
      status:          _selectedStatus,
      registeredBy:    auth.currentUser?.uid,
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final catData  = AppCategories.all[_selectedCategory];
    final catColor = catData?.color ?? AppColors.primary;

    final svc  = context.watch<FormConfigService>();
    final subs = svc.getSubcategoryNames(_selectedCategory);

    return Scaffold(
      appBar: AppBar(
        title: Text(_editFarmer != null ? 'Edit Registration' : 'New Registration'),
        actions: [
          _isSaving
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    ),
                  ),
                )
              : TextButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save, color: Colors.white),
                  label: const Text('Save',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [

            // ── 1. Personal Info ─────────────────────────────────────────
            _Section(title: 'Personal Info', icon: Icons.person_outline),
            const SizedBox(height: 12),

            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Full Name *',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Mobile Number *',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 15,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (v.length < 7) return 'Invalid number';
                return null;
              },
            ),

            // ── 2. Location ──────────────────────────────────────────────
            const SizedBox(height: 20),
            _Section(title: 'Location', icon: Icons.location_on_outlined),
            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: _isLocating ? null : _detectLocation,
              icon: _isLocating
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location),
              label: Text(_isLocating
                  ? 'Detecting…'
                  : _latitude != null
                      ? 'GPS: ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}  ✓'
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
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
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

            // ── 3. Category ──────────────────────────────────────────────
            const SizedBox(height: 24),
            _Section(title: 'Category', icon: Icons.category_outlined),
            const SizedBox(height: 12),

            InkWell(
              onTap: _openCategorySheet,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _selectedCategory.isEmpty
                      ? AppColors.veryLight
                      : catColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedCategory.isEmpty
                        ? AppColors.light
                        : catColor.withOpacity(0.4),
                    width: _selectedCategory.isEmpty ? 1 : 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: catColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        catData?.icon ?? Icons.category_outlined,
                        color: catColor, size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Category *',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.textMedium)),
                          Text(
                            _selectedCategory.isEmpty
                                ? 'Tap to select category'
                                : _selectedCategory,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: _selectedCategory.isEmpty
                                  ? FontWeight.normal
                                  : FontWeight.w700,
                              color: _selectedCategory.isEmpty
                                  ? AppColors.textMedium.withOpacity(0.6)
                                  : catColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.expand_more, color: catColor),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Subcategory dropdown — items come from FormConfigService
            if (svc.isLoading && _selectedCategory.isNotEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              DropdownButtonFormField<String>(
                value: _selectedSubcategory.isEmpty ? null : _selectedSubcategory,
                decoration: InputDecoration(
                  labelText: 'Subcategory *',
                  prefixIcon: Icon(Icons.list_alt_outlined, color: catColor),
                  filled: true,
                  fillColor: _selectedCategory.isEmpty
                      ? AppColors.divider.withOpacity(0.3)
                      : AppColors.veryLight,
                ),
                hint: Text(_selectedCategory.isEmpty
                    ? 'Select a category first'
                    : 'Select subcategory'),
                items: subs
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: _selectedCategory.isEmpty
                    ? null
                    : (v) => setState(() => _selectedSubcategory = v ?? ''),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Select a subcategory' : null,
              ),

            // ── 4. Dynamic fields ────────────────────────────────────────
            if (_selectedCategory.isNotEmpty && _selectedSubcategory.isNotEmpty) ...[
              const SizedBox(height: 24),
              _Section(
                title: '$_selectedCategory Details',
                icon: catData?.icon ?? Icons.info_outline,
                color: catColor,
              ),
              const SizedBox(height: 12),
              ..._buildDynamicFields(catColor),
            ],

            // ── 5. Land Details ──────────────────────────────────────────
            const SizedBox(height: 24),
            _Section(title: 'Land Details', icon: Icons.landscape_outlined),
            const SizedBox(height: 12),

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
                  value: _selectedLandUnit,
                  decoration: const InputDecoration(labelText: 'Unit'),
                  items: _landUnits
                      .map((u) =>
                          DropdownMenuItem(value: u, child: Text(u)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedLandUnit = v!),
                ),
              ),
            ]),

            // ── 6. Status ────────────────────────────────────────────────
            const SizedBox(height: 24),
            _Section(title: 'Status', icon: Icons.toggle_on_outlined),
            const SizedBox(height: 12),

            Row(
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
                      fontWeight:
                          sel ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
            ),

            // ── Submit ───────────────────────────────────────────────────
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

  // ── Dynamic field builder ─────────────────────────────────────────────────

  List<Widget> _buildDynamicFields(Color catColor) {
    final fields = _fieldsForCategory(_selectedCategory);
    return fields
        .map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildApiField(f, catColor),
            ))
        .toList();
  }

  Widget _buildApiField(ApiField f, Color catColor) {
    switch (f.type) {
      case 'TEXT':
        return TextFormField(
          controller: _dynTextCtrl[f.key],
          decoration: InputDecoration(
            labelText: f.required ? '${f.label} *' : f.label,
            prefixIcon: Icon(Icons.edit_note_outlined, color: catColor),
          ),
          textCapitalization: TextCapitalization.sentences,
          validator: f.required
              ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
              : null,
        );

      case 'NUMBER':
        return TextFormField(
          controller: _dynTextCtrl[f.key],
          decoration: InputDecoration(
            labelText: f.required ? '${f.label} *' : f.label,
            prefixIcon: Icon(Icons.numbers_outlined, color: catColor),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
          ],
          validator: f.required
              ? (v) => (v == null || v.isEmpty) ? 'Required' : null
              : null,
        );

      case 'DROPDOWN':
        return DropdownButtonFormField<String>(
          value: (_dynDropdown[f.key]?.isEmpty ?? true)
              ? null
              : _dynDropdown[f.key],
          decoration: InputDecoration(
            labelText: f.required ? '${f.label} *' : f.label,
            prefixIcon:
                Icon(Icons.arrow_drop_down_circle_outlined, color: catColor),
          ),
          hint: Text('Select ${f.label}'),
          items: f.options
              .map((o) => DropdownMenuItem(value: o.name, child: Text(o.name)))
              .toList(),
          onChanged: (v) => setState(() => _dynDropdown[f.key] = v ?? ''),
          validator: f.required
              ? (v) => (v == null || v.isEmpty) ? 'Required' : null
              : null,
        );

      case 'BUTTON':
        final popup = f.popup;
        if (popup == null) return const SizedBox.shrink();
        final filled = popup.fields.where((pf) {
          if (pf.type == 'DROPDOWN') return (_dynDropdown[pf.key] ?? '').isNotEmpty;
          return (_dynTextCtrl[pf.key]?.text ?? '').isNotEmpty;
        }).length;
        final total = popup.fields.length;
        return OutlinedButton.icon(
          onPressed: () => _openPopupSheet(popup, catColor),
          icon: Icon(
            filled > 0 ? Icons.check_circle_outline : Icons.add_circle_outline,
            color: filled > 0 ? catColor : AppColors.textMedium,
          ),
          label: Text(
            filled > 0
                ? '${f.label}  ($filled / $total filled)'
                : f.label,
            style: TextStyle(
              color: filled > 0 ? catColor : AppColors.textMedium,
            ),
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            side: BorderSide(
              color: filled > 0 ? catColor : AppColors.light,
              width: filled > 0 ? 1.5 : 1,
            ),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  void _openPopupSheet(ApiPopup popup, Color catColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PopupFieldSheet(
        popup: popup,
        catColor: catColor,
        textCtrl: _dynTextCtrl,
        dropdown: _dynDropdown,
        onSaved: (updatedDropdown) {
          setState(() {
            updatedDropdown.forEach((k, v) => _dynDropdown[k] = v);
          });
        },
      ),
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
          child: Divider(color: color.withOpacity(0.35), thickness: 1.5)),
    ]);
  }
}

// ─── Category Bottom Sheet ────────────────────────────────────────────────────
class _CategorySheet extends StatelessWidget {
  final ValueChanged<String> onSelected;
  const _CategorySheet({required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Select Category',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dark)),
          ),
          const SizedBox(height: 4),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Subcategory will appear as dropdown inside the form',
                style: TextStyle(fontSize: 12, color: AppColors.textMedium)),
          ),
          const SizedBox(height: 16),
          ...AppCategories.all.entries.map((e) {
            final color = e.value.color;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => onSelected(e.key),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      colors: [color.withOpacity(0.08), color.withOpacity(0.04)],
                    ),
                    border: Border.all(color: color.withOpacity(0.25)),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(e.value.icon, color: color, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.key,
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: color)),
                          Text(
                            '${e.value.subcategories.length} subcategories',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMedium),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: color),
                  ]),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Popup Field Sheet ────────────────────────────────────────────────────────
class _PopupFieldSheet extends StatefulWidget {
  final ApiPopup popup;
  final Color catColor;
  final Map<String, TextEditingController> textCtrl;
  final Map<String, String> dropdown;
  final void Function(Map<String, String> updatedDropdown) onSaved;

  const _PopupFieldSheet({
    required this.popup,
    required this.catColor,
    required this.textCtrl,
    required this.dropdown,
    required this.onSaved,
  });

  @override
  State<_PopupFieldSheet> createState() => _PopupFieldSheetState();
}

class _PopupFieldSheetState extends State<_PopupFieldSheet> {
  late Map<String, String> _localDropdown;

  @override
  void initState() {
    super.initState();
    // Copy only the dropdown keys that belong to this popup
    _localDropdown = {
      for (final f in widget.popup.fields)
        if (f.type == 'DROPDOWN') f.key: widget.dropdown[f.key] ?? '',
    };
  }

  void _save() {
    widget.onSaved(_localDropdown);
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
              width: 40, height: 4,
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
    switch (f.type) {
      case 'TEXT':
        return TextFormField(
          controller: widget.textCtrl[f.key],
          decoration: InputDecoration(
            labelText: f.label,
            prefixIcon: Icon(Icons.edit_note_outlined, color: color),
          ),
          textCapitalization: TextCapitalization.sentences,
        );

      case 'NUMBER':
        return TextFormField(
          controller: widget.textCtrl[f.key],
          decoration: InputDecoration(
            labelText: f.label,
            prefixIcon: Icon(Icons.numbers_outlined, color: color),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
          ],
        );

      case 'DROPDOWN':
        return DropdownButtonFormField<String>(
          value: (_localDropdown[f.key]?.isEmpty ?? true)
              ? null
              : _localDropdown[f.key],
          decoration: InputDecoration(
            labelText: f.label,
            prefixIcon:
                Icon(Icons.arrow_drop_down_circle_outlined, color: color),
          ),
          hint: Text('Select ${f.label}'),
          items: f.options
              .map((o) => DropdownMenuItem(value: o.name, child: Text(o.name)))
              .toList(),
          onChanged: (v) =>
              setState(() => _localDropdown[f.key] = v ?? ''),
        );

      default:
        return const SizedBox.shrink();
    }
  }
}
