/// Dynamic form fields for the Greenated green carbon registration form.
/// Fields are rendered automatically based on the selected category.

enum FieldType { text, number, dropdown }

class DynamicField {
  final String key;
  final String label;
  final FieldType type;
  final List<String> options;
  final String hint;
  final bool required;

  const DynamicField({
    required this.key,
    required this.label,
    required this.type,
    this.options = const [],
    this.hint = '',
    this.required = false,
  });
}

/// Returns the dynamic fields for a given Greenated category.
List<DynamicField> getDynamicFields(String category) {
  return _categoryFields[category] ?? [];
}

const Map<String, List<DynamicField>> _categoryFields = {

  // ─── Agroforestry ──────────────────────────────────────────────────────
  'Agroforestry': [
    DynamicField(
      key: 'treeSpecies',
      label: 'Tree Species',
      type: FieldType.text,
      hint: 'e.g., Teak, Neem, Bamboo, Moringa',
      required: true,
    ),
    DynamicField(
      key: 'treesPerAcre',
      label: 'Number of Trees per Acre',
      type: FieldType.number,
      hint: 'e.g., 100',
      required: true,
    ),
    DynamicField(
      key: 'intercrop',
      label: 'Intercrop / Understory',
      type: FieldType.text,
      hint: 'Crops or plants grown between trees',
    ),
    DynamicField(
      key: 'plantationAge',
      label: 'Plantation Age (Years)',
      type: FieldType.number,
      hint: 'Age of existing trees',
    ),
    DynamicField(
      key: 'carbonStock',
      label: 'Estimated Carbon Stock (tCO₂e/ha)',
      type: FieldType.number,
      hint: 'Estimated carbon sequestered',
    ),
    DynamicField(
      key: 'certification',
      label: 'Carbon Certification',
      type: FieldType.dropdown,
      options: [
        'None',
        'VCS / Verra',
        'Gold Standard',
        'Plan Vivo',
        'CDM (UNFCCC)',
        'I-REC',
        'In Progress',
      ],
    ),
  ],

  // ─── Soil Carbon ───────────────────────────────────────────────────────
  'Soil Carbon': [
    DynamicField(
      key: 'currentPractice',
      label: 'Current Practice',
      type: FieldType.dropdown,
      options: [
        'Cover Cropping',
        'No-till / Reduced Tillage',
        'Rotational Grazing',
        'Compost Application',
        'Biosolids Application',
        'Wetland Restoration',
        'Grassland Management',
      ],
      required: true,
    ),
    DynamicField(
      key: 'baselineSOC',
      label: 'Baseline Soil Organic Carbon (%)',
      type: FieldType.number,
      hint: 'Current SOC level (0–10%)',
      required: true,
    ),
    DynamicField(
      key: 'targetSOC',
      label: 'Target SOC Increase (%)',
      type: FieldType.number,
      hint: 'Expected improvement',
    ),
    DynamicField(
      key: 'previousLandUse',
      label: 'Previous Land Use',
      type: FieldType.dropdown,
      options: [
        'Cropland',
        'Degraded Land',
        'Grassland',
        'Wetland',
        'Fallow',
        'Forest Clearance',
      ],
    ),
    DynamicField(
      key: 'measurementMethod',
      label: 'SOC Measurement Method',
      type: FieldType.dropdown,
      options: [
        'Lab Analysis (Walkley-Black)',
        'Lab Analysis (LOI)',
        'Field Survey',
        'Remote Sensing',
        'Modelling (RothC / CENTURY)',
        'Not Measured Yet',
      ],
    ),
    DynamicField(
      key: 'yearsInPractice',
      label: 'Years Under This Practice',
      type: FieldType.number,
      hint: 'How long this practice has been followed',
    ),
  ],

  // ─── Biochar ────────────────────────────────────────────────────────────
  'Biochar': [
    DynamicField(
      key: 'feedstockType',
      label: 'Feedstock Type',
      type: FieldType.dropdown,
      options: [
        'Wood / Woody Biomass',
        'Crop Residue (Rice Husk, Straw)',
        'Bamboo',
        'Municipal Solid Waste',
        'Livestock Manure',
        'Sewage Sludge',
        'Mixed Feedstock',
      ],
      required: true,
    ),
    DynamicField(
      key: 'productionMethod',
      label: 'Production Method',
      type: FieldType.dropdown,
      options: [
        'Slow Pyrolysis',
        'Fast Pyrolysis',
        'Gasification',
        'Hydrothermal Carbonization (HTC)',
        'Flash Carbonization',
        'Traditional Kiln',
      ],
      required: true,
    ),
    DynamicField(
      key: 'applicationRate',
      label: 'Application Rate (t/ha)',
      type: FieldType.number,
      hint: 'Tonnes of biochar per hectare',
      required: true,
    ),
    DynamicField(
      key: 'carbonContent',
      label: 'Biochar Carbon Content (%)',
      type: FieldType.number,
      hint: 'Fixed carbon % (typically 60–90%)',
    ),
    DynamicField(
      key: 'applicationFrequency',
      label: 'Application Frequency',
      type: FieldType.dropdown,
      options: [
        'One-time Application',
        'Annual',
        'Bi-annual',
        'Seasonal',
        'As Needed',
      ],
    ),
    DynamicField(
      key: 'soilImpact',
      label: 'Observed Soil Impact',
      type: FieldType.dropdown,
      options: [
        'Improved Water Retention',
        'Increased Crop Yield',
        'Improved pH Balance',
        'Reduced Nutrient Leaching',
        'No Observable Change Yet',
      ],
    ),
  ],
};
