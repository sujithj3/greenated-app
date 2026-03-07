import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/api/api_models.dart';
import '../config/env_config.dart';

class FormConfigService extends ChangeNotifier {
  static String get _apiUrl => '${EnvConfig.apiBaseUrl}/category-form-config';

  List<ApiCategory> _categories = [];
  bool _isLoading = false;
  String? _error;

  List<ApiCategory> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoaded => _categories.isNotEmpty;

  Future<void> fetchCategories() async {
    if (_categories.isNotEmpty) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      if (EnvConfig.isDemoMode) {
        await Future.delayed(const Duration(milliseconds: 600));
        _categories = _buildDemoCategories();
      } else {
        final res = await http.get(Uri.parse(_apiUrl));
        if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        _categories = (body['data'] as List<dynamic>)
            .map((c) => ApiCategory.fromJson(c as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('FormConfigService: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  ApiCategory? getCategoryByName(String name) {
    try {
      return _categories.firstWhere((c) => c.name == name);
    } catch (_) {
      return null;
    }
  }

  List<String> getSubcategoryNames(String categoryName) {
    return getCategoryByName(categoryName)
            ?.subcategories
            .map((s) => s.name)
            .toList() ??
        [];
  }

  List<ApiField> getFields(String categoryName, String subcategoryName) {
    return getCategoryByName(categoryName)
            ?.findSubcategory(subcategoryName)
            ?.primaryForm
            ?.fields ??
        [];
  }

  // ── Demo data ───────────────────────────────────────────────────────────────

  static List<ApiCategory> _buildDemoCategories() {
    // ── Agroforestry ──────────────────────────────────────────────────────────
    final agroFields = <ApiField>[
      const ApiField(
        fieldId: 10,
        label: 'Tree Species',
        key: 'tree_species',
        type: 'TEXT',
        required: true,
      ),
      const ApiField(
        fieldId: 11,
        label: 'Trees per Acre',
        key: 'trees_per_acre',
        type: 'NUMBER',
        required: true,
      ),
      ApiField(
        fieldId: 12,
        label: 'Carbon Certification',
        key: 'certification',
        type: 'DROPDOWN',
        required: false,
        options: const [
          ApiOption(id: 1, name: 'None'),
          ApiOption(id: 2, name: 'VCS / Verra'),
          ApiOption(id: 3, name: 'Gold Standard'),
          ApiOption(id: 4, name: 'Plan Vivo'),
          ApiOption(id: 5, name: 'CDM (UNFCCC)'),
          ApiOption(id: 6, name: 'In Progress'),
        ],
      ),
      ApiField(
        fieldId: 13,
        label: 'Add Plantation Details',
        key: 'plantation_details',
        type: 'BUTTON',
        required: false,
        popup: ApiPopup(
          title: 'Plantation Details',
          fields: const [
            ApiField(
                fieldId: 131,
                label: 'Intercrop / Understory',
                key: 'intercrop',
                type: 'TEXT',
                required: false),
            ApiField(
                fieldId: 132,
                label: 'Plantation Age (Years)',
                key: 'plantation_age',
                type: 'NUMBER',
                required: false),
            ApiField(
                fieldId: 133,
                label: 'Carbon Stock (tCO\u2082e/ha)',
                key: 'carbon_stock',
                type: 'NUMBER',
                required: false),
          ],
        ),
      ),
    ];

    // ── Soil Carbon ───────────────────────────────────────────────────────────
    final soilFields = <ApiField>[
      ApiField(
        fieldId: 20,
        label: 'Current Practice',
        key: 'current_practice',
        type: 'DROPDOWN',
        required: true,
        options: const [
          ApiOption(id: 1, name: 'Cover Cropping'),
          ApiOption(id: 2, name: 'No-till / Reduced Tillage'),
          ApiOption(id: 3, name: 'Rotational Grazing'),
          ApiOption(id: 4, name: 'Compost Application'),
          ApiOption(id: 5, name: 'Biosolids Application'),
          ApiOption(id: 6, name: 'Wetland Restoration'),
          ApiOption(id: 7, name: 'Grassland Management'),
        ],
      ),
      const ApiField(
        fieldId: 21,
        label: 'Baseline SOC (%)',
        key: 'baseline_soc',
        type: 'NUMBER',
        required: true,
      ),
      ApiField(
        fieldId: 22,
        label: 'Previous Land Use',
        key: 'previous_land_use',
        type: 'DROPDOWN',
        required: false,
        options: const [
          ApiOption(id: 1, name: 'Cropland'),
          ApiOption(id: 2, name: 'Degraded Land'),
          ApiOption(id: 3, name: 'Grassland'),
          ApiOption(id: 4, name: 'Wetland'),
          ApiOption(id: 5, name: 'Fallow'),
          ApiOption(id: 6, name: 'Forest Clearance'),
        ],
      ),
      ApiField(
        fieldId: 23,
        label: 'Add Soil Analysis',
        key: 'soil_analysis',
        type: 'BUTTON',
        required: false,
        popup: ApiPopup(
          title: 'Soil Analysis Details',
          fields: [
            const ApiField(
                fieldId: 231,
                label: 'Target SOC (%)',
                key: 'target_soc',
                type: 'NUMBER',
                required: false),
            ApiField(
              fieldId: 232,
              label: 'Measurement Method',
              key: 'measurement_method',
              type: 'DROPDOWN',
              required: false,
              options: const [
                ApiOption(id: 1, name: 'Lab Analysis (Walkley-Black)'),
                ApiOption(id: 2, name: 'Lab Analysis (LOI)'),
                ApiOption(id: 3, name: 'Field Survey'),
                ApiOption(id: 4, name: 'Remote Sensing'),
                ApiOption(id: 5, name: 'Modelling (RothC / CENTURY)'),
                ApiOption(id: 6, name: 'Not Measured Yet'),
              ],
            ),
            const ApiField(
                fieldId: 233,
                label: 'Years Under Practice',
                key: 'years_in_practice',
                type: 'NUMBER',
                required: false),
          ],
        ),
      ),
    ];

    // ── Biochar ───────────────────────────────────────────────────────────────
    final biocharFields = <ApiField>[
      ApiField(
        fieldId: 30,
        label: 'Feedstock Type',
        key: 'feedstock_type',
        type: 'DROPDOWN',
        required: true,
        options: const [
          ApiOption(id: 1, name: 'Wood / Woody Biomass'),
          ApiOption(id: 2, name: 'Crop Residue (Rice Husk, Straw)'),
          ApiOption(id: 3, name: 'Bamboo'),
          ApiOption(id: 4, name: 'Municipal Solid Waste'),
          ApiOption(id: 5, name: 'Livestock Manure'),
          ApiOption(id: 6, name: 'Sewage Sludge'),
          ApiOption(id: 7, name: 'Mixed Feedstock'),
        ],
      ),
      ApiField(
        fieldId: 31,
        label: 'Production Method',
        key: 'production_method',
        type: 'DROPDOWN',
        required: true,
        options: const [
          ApiOption(id: 1, name: 'Slow Pyrolysis'),
          ApiOption(id: 2, name: 'Fast Pyrolysis'),
          ApiOption(id: 3, name: 'Gasification'),
          ApiOption(id: 4, name: 'Hydrothermal Carbonization (HTC)'),
          ApiOption(id: 5, name: 'Flash Carbonization'),
          ApiOption(id: 6, name: 'Traditional Kiln'),
        ],
      ),
      const ApiField(
        fieldId: 32,
        label: 'Application Rate (t/ha)',
        key: 'application_rate',
        type: 'NUMBER',
        required: true,
      ),
      ApiField(
        fieldId: 33,
        label: 'Add Biochar Details',
        key: 'biochar_details',
        type: 'BUTTON',
        required: false,
        popup: ApiPopup(
          title: 'Biochar Details',
          fields: [
            const ApiField(
                fieldId: 331,
                label: 'Carbon Content (%)',
                key: 'carbon_content',
                type: 'NUMBER',
                required: false),
            ApiField(
              fieldId: 332,
              label: 'Application Frequency',
              key: 'application_frequency',
              type: 'DROPDOWN',
              required: false,
              options: const [
                ApiOption(id: 1, name: 'One-time Application'),
                ApiOption(id: 2, name: 'Annual'),
                ApiOption(id: 3, name: 'Bi-annual'),
                ApiOption(id: 4, name: 'Seasonal'),
                ApiOption(id: 5, name: 'As Needed'),
              ],
            ),
            ApiField(
              fieldId: 333,
              label: 'Observed Soil Impact',
              key: 'soil_impact',
              type: 'DROPDOWN',
              required: false,
              options: const [
                ApiOption(id: 1, name: 'Improved Water Retention'),
                ApiOption(id: 2, name: 'Increased Crop Yield'),
                ApiOption(id: 3, name: 'Improved pH Balance'),
                ApiOption(id: 4, name: 'Reduced Nutrient Leaching'),
                ApiOption(id: 5, name: 'No Observable Change Yet'),
              ],
            ),
          ],
        ),
      ),
    ];

    // ── Build helper ──────────────────────────────────────────────────────────
    List<ApiSubcategory> buildSubs(
      List<String> names,
      int baseId,
      List<ApiField> fields,
    ) {
      return names
          .asMap()
          .entries
          .map((e) => ApiSubcategory(
                id: baseId + e.key,
                name: e.value,
                forms: [
                  ApiForm(
                    formId: baseId * 10 + e.key,
                    formName: 'Farmer Registration',
                    fields: fields,
                  ),
                ],
              ))
          .toList();
    }

    return [
      ApiCategory(
        id: 1,
        name: 'Agroforestry',
        subcategories: buildSubs(
          [
            'Silvopasture',
            'Alley Cropping',
            'Forest Farming',
            'Riparian Buffers',
            'Windbreaks & Shelterbelts',
            'Multi-strata Systems',
            'Homegardens',
            'Taungya System'
          ],
          100,
          agroFields,
        ),
      ),
      ApiCategory(
        id: 2,
        name: 'Soil Carbon',
        subcategories: buildSubs(
          [
            'Cover Cropping',
            'No-till / Reduced Tillage',
            'Rotational Grazing',
            'Compost Application',
            'Biosolids Application',
            'Wetland Restoration',
            'Grassland Management'
          ],
          200,
          soilFields,
        ),
      ),
      ApiCategory(
        id: 3,
        name: 'Biochar',
        subcategories: buildSubs(
          [
            'Wood Biochar',
            'Crop Residue Biochar',
            'Bamboo Biochar',
            'Municipal Waste Biochar',
            'Co-composting with Biochar',
            'Livestock Manure Biochar'
          ],
          300,
          biocharFields,
        ),
      ),
    ];
  }
}
