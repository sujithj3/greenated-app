import 'package:flutter/foundation.dart';
import '../../config/env_config.dart';
import '../../models/api/api_models.dart';
import '../../models/farmer/farmer_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/form_config_service.dart';
import '../../services/location_service.dart';

class FarmerFormViewModel extends ChangeNotifier {
  final AuthService _authService;
  final FirestoreService _firestoreService;
  final FormConfigService _formConfigService;
  final LocationService _locationService;

  FarmerFormViewModel(
    this._authService,
    this._firestoreService,
    this._formConfigService,
    this._locationService,
  );

  // State
  String selectedCategory = '';
  String selectedSubcategory = '';
  String selectedLandUnit = 'Acres';
  String selectedStatus = 'Active';
  List<Map<String, double>> landCoordinates = [];
  double? latitude;
  double? longitude;
  bool isSaving = false;
  bool isLocating = false;
  FarmerModel? editFarmer;

  // Dynamic field state - tracks which keys are dropdowns vs text
  final Map<String, String> dynDropdownValues = {};
  final Set<String> _textFieldKeys = {};
  final Set<String> _numberFieldKeys = {};

  final List<String> landUnits = const [
    'Acres',
    'Hectares',
    'Bigha',
    'Sq. Meters'
  ];

  // FormConfigService proxies
  bool get isConfigLoading => _formConfigService.isLoading;

  Future<void> fetchConfig() async {
    await _formConfigService.fetchCategories();
    notifyListeners();
  }

  List<String> get subcategoryNames =>
      _formConfigService.getSubcategoryNames(selectedCategory);

  List<ApiField> get fieldsForCategory {
    final cat = _formConfigService.getCategoryByName(selectedCategory);
    if (cat == null || cat.subcategories.isEmpty) return [];
    return cat.subcategories.first.primaryForm?.fields ?? [];
  }

  // Init from route arguments
  void init(Map? args) {
    if (args == null) return;
    if (args['category'] != null && selectedCategory.isEmpty) {
      setCategory(args['category'] as String);
    }
    if (args['farmer'] != null && editFarmer == null) {
      editFarmer = args['farmer'] as FarmerModel;
    }
  }

  void setCategory(String cat) {
    selectedCategory = cat;
    selectedSubcategory = '';
    _rebuildDynFieldKeys(cat);
    notifyListeners();
  }

  void setSubcategory(String sub) {
    selectedSubcategory = sub;
    notifyListeners();
  }

  void setLandUnit(String unit) {
    selectedLandUnit = unit;
    notifyListeners();
  }

  void setStatus(String status) {
    selectedStatus = status;
    notifyListeners();
  }

  void setDropdownValue(String key, String value) {
    dynDropdownValues[key] = value;
    notifyListeners();
  }

  void _rebuildDynFieldKeys(String category) {
    _textFieldKeys.clear();
    _numberFieldKeys.clear();
    dynDropdownValues.clear();

    for (final f in fieldsForCategory) {
      _initFieldKey(f);
      if (f.type == 'BUTTON' && f.popup != null) {
        for (final pf in f.popup!.fields) {
          _initFieldKey(pf);
        }
      }
    }
  }

  void _initFieldKey(ApiField f) {
    if (f.type == 'DROPDOWN') {
      dynDropdownValues[f.key] = '';
    } else if (f.type == 'TEXT') {
      _textFieldKeys.add(f.key);
    } else if (f.type == 'NUMBER') {
      _numberFieldKeys.add(f.key);
    }
  }

  /// Returns the set of keys that need TextEditingControllers in the View.
  Set<String> get textFieldKeys => {..._textFieldKeys, ..._numberFieldKeys};

  // Location
  Future<AddressResult?> detectLocation() async {
    if (EnvConfig.isDemoMode) {
      latitude = 26.8467;
      longitude = 80.9462;
      notifyListeners();
      return const AddressResult(
        address: 'Near Panchayat Bhavan, Village Road',
        village: 'Sundarpur',
        district: 'Lucknow',
        state: 'Uttar Pradesh',
      );
    }

    isLocating = true;
    notifyListeners();
    try {
      final pos = await _locationService.getCurrentPosition();
      latitude = pos.latitude;
      longitude = pos.longitude;
      final result =
          await _locationService.reverseGeocode(pos.latitude, pos.longitude);
      isLocating = false;
      notifyListeners();
      return result;
    } catch (e) {
      isLocating = false;
      notifyListeners();
      rethrow;
    }
  }

  void setLandResult(Map<String, dynamic> result) {
    final area = result['area'] as double? ?? 0;
    final coords = result['coordinates'] as List<Map<String, double>>? ?? [];
    landCoordinates = coords;
    if (area > 0) {
      selectedLandUnit = 'Acres';
    }
    notifyListeners();
  }

  // Save
  Future<bool> save(
    Map<String, String> textFieldValues, {
    required String name,
    required String phone,
    required String address,
    required String village,
    required String district,
    required String state,
    required double landArea,
  }) async {
    isSaving = true;
    notifyListeners();

    final Map<String, String> dynValues = {};
    textFieldValues.forEach((k, v) {
      if (v.isNotEmpty) dynValues[k] = v;
    });
    dynDropdownValues.forEach((k, v) {
      if (v.isNotEmpty) dynValues[k] = v;
    });

    final farmer = FarmerModel(
      id: editFarmer?.id,
      name: name,
      phone: phone,
      address: address,
      village: village,
      district: district,
      state: state,
      latitude: latitude,
      longitude: longitude,
      category: selectedCategory,
      subcategory: selectedSubcategory,
      landArea: landArea,
      landUnit: selectedLandUnit,
      landCoordinates: landCoordinates,
      dynamicFields: dynValues,
      status: selectedStatus,
      registeredBy: _authService.currentUser?.uid,
    );

    try {
      if (editFarmer != null) {
        await _firestoreService.updateFarmer(farmer);
      } else {
        await _firestoreService.addFarmer(farmer);
      }
      isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      isSaving = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Populate ViewModel state from an existing farmer (for editing).
  /// Returns the farmer's dynamicFields so the View can set TextEditingControllers.
  Map<String, String> populateFromFarmer(FarmerModel f) {
    selectedCategory = f.category;
    selectedSubcategory = f.subcategory;
    selectedLandUnit = f.landUnit;
    selectedStatus = f.status;
    landCoordinates = f.landCoordinates;
    latitude = f.latitude;
    longitude = f.longitude;
    _rebuildDynFieldKeys(f.category);

    // Set dropdown values from farmer's dynamic fields
    f.dynamicFields.forEach((key, value) {
      if (dynDropdownValues.containsKey(key)) {
        dynDropdownValues[key] = value;
      }
    });

    notifyListeners();
    // Return text field values for the View to set on controllers
    return Map.fromEntries(
      f.dynamicFields.entries.where((e) => textFieldKeys.contains(e.key)),
    );
  }
}
