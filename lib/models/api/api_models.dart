/// Models that match the backend API response for category form configuration.
///
/// API shape:
/// { statusCode, status, message, data: [ ApiCategory ] }
library;

// ─── FieldType (data type of a field) ─────────────────────────────────────────

enum FieldType {
  string,
  integer,
  decimal,
  boolean,
  arrayString,
  arrayInt,
  arrayDict,
  dict,
  image,
  multimedia,
  unknown;

  static FieldType fromApiValue(Object? rawValue) {
    final value = (rawValue as String? ?? '').trim().toUpperCase();
    return switch (value) {
      'STRING' => FieldType.string,
      'INT' => FieldType.integer,
      'DOUBLE' => FieldType.decimal,
      'BOOL' => FieldType.boolean,
      'ARRAY-STRING' || 'ARRAY_STRING' => FieldType.arrayString,
      'ARRAY-INT' || 'ARRAY_INT' => FieldType.arrayInt,
      'ARRAY-DICT' || 'ARRAY_DICT' => FieldType.arrayDict,
      'DICT' => FieldType.dict,
      'IMAGE' => FieldType.image,
      'MULTIMEDIA' => FieldType.multimedia,
      // Legacy fallback
      'NUMBER' => FieldType.integer,
      _ => FieldType.unknown,
    };
  }
}

// ─── FieldStyle (UI rendering style) ──────────────────────────────────────────

enum FieldStyle {
  text,
  number,
  dropdown,
  checkbox,
  radio,
  date,
  camera,
  file,
  cameraFile,
  popupForm,
  unknown;

  static FieldStyle fromApiValue(Object? rawValue) {
    final value = (rawValue as String? ?? '').trim().toUpperCase();
    return switch (value) {
      'TEXT' => FieldStyle.text,
      'NUMBER' => FieldStyle.number,
      'DROPDOWN' => FieldStyle.dropdown,
      'CHECKBOX' => FieldStyle.checkbox,
      'RADIO' => FieldStyle.radio,
      'DATE' => FieldStyle.date,
      'CAMERA' => FieldStyle.camera,
      'FILE' => FieldStyle.file,
      'CAMERA_FILE' => FieldStyle.cameraFile,
      'POPUP_FORM' => FieldStyle.popupForm,
      // Legacy backward compat
      'BUTTON' => FieldStyle.popupForm,
      _ => FieldStyle.unknown,
    };
  }
}

// ─── Option (inside DROPDOWN / RADIO field) ─────────────────────────────────

class ApiOption {
  final int id;
  final String name;

  const ApiOption({required this.id, required this.name});

  factory ApiOption.fromJson(Map<String, dynamic> j) {
    final rawName = j['name'] ?? j['label'] ?? j['value'];
    final String name = rawName?.toString() ?? '';
    final rawId = j['id'] ?? j['option_id'] ?? j['value'];
    return ApiOption(
      id: _asInt(rawId, fallback: name.hashCode),
      name: name,
    );
  }
}

// ─── ApiField ────────────────────────────────────────────────────────────────

class ApiField {
  final int fieldId;
  final String label;
  final String key;
  final FieldType fieldType;
  final FieldStyle fieldStyle;
  final bool required;
  final List<ApiOption> options; // for DROPDOWN / RADIO
  final List<ApiField> subFields; // for POPUP-FORM (nested field definitions)

  /// Whether this field opens a sub-form.
  bool get isPopupForm => fieldStyle == FieldStyle.popupForm;

  /// Option names as plain strings (convenience for radio / dropdown).
  List<String> get fieldData => options.map((o) => o.name).toList();

  const ApiField({
    required this.fieldId,
    required this.label,
    required this.key,
    required this.fieldType,
    required this.fieldStyle,
    required this.required,
    this.options = const [],
    this.subFields = const [],
  });

  factory ApiField.fromJson(Map<String, dynamic> j) {
    final fieldType = FieldType.fromApiValue(j['field_type']);
    final fieldStyle = FieldStyle.fromApiValue(j['field_style']);

    final rawOptions = j['options'] as List<dynamic>? ?? [];

    // Parse options based on resolved style:
    // - popupForm: options contains nested field definitions
    // - everything else: options contains dropdown/radio choices
    List<ApiOption> options = const [];
    List<ApiField> subFields = const [];

    if (fieldStyle == FieldStyle.popupForm) {
      subFields = rawOptions
          .whereType<Map<String, dynamic>>()
          .map((o) => ApiField.fromJson(o))
          .toList();
    } else {
      options = rawOptions
          .whereType<Map<String, dynamic>>()
          .map((o) => ApiOption.fromJson(o))
          .toList();
    }

    return ApiField(
      fieldId: _asInt(j['field_id']),
      label: (j['label']?.toString() ?? ''),
      key: (j['key']?.toString() ?? ''),
      fieldType: fieldType,
      fieldStyle: fieldStyle,
      required: j['required'] as bool? ?? false,
      options: options,
      subFields: subFields,
    );
  }
}

// ─── ApiForm ─────────────────────────────────────────────────────────────────
class ApiForm {
  final int formId;
  final String formName;
  final bool geoLocationRequired;
  final List<ApiField> fields;

  const ApiForm({
    required this.formId,
    required this.formName,
    this.geoLocationRequired = false,
    this.fields = const [],
  });

  factory ApiForm.fromJson(Map<String, dynamic> j) {
    return ApiForm(
      formId: _asInt(j['form_id']),
      formName: j['form_name']?.toString() ?? '',
      geoLocationRequired: j['geoLocationRequired'] as bool? ?? false,
      fields: (j['fields'] as List<dynamic>? ?? [])
          .map((f) => ApiField.fromJson(f as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ─── ApiSubcategory ───────────────────────────────────────────────────────────
class ApiSubcategory {
  final int id;
  final String name;
  final List<ApiForm> forms;

  const ApiSubcategory({
    required this.id,
    required this.name,
    required this.forms,
  });

  /// Returns the first (primary) form for this subcategory, or null.
  ApiForm? get primaryForm => forms.isNotEmpty ? forms.first : null;

  factory ApiSubcategory.fromJson(Map<String, dynamic> j) => ApiSubcategory(
        id: _asInt(j['subcategory_id']),
        name: j['subcategory_name']?.toString() ?? '',
        forms: (j['forms'] as List<dynamic>? ?? [])
            .map((f) => ApiForm.fromJson(f as Map<String, dynamic>))
            .toList(),
      );
}

// ─── ApiCategory ─────────────────────────────────────────────────────────────
class ApiCategory {
  final int id;
  final String name;
  final List<ApiSubcategory> subcategories;

  const ApiCategory({
    required this.id,
    required this.name,
    required this.subcategories,
  });

  factory ApiCategory.fromJson(Map<String, dynamic> j) => ApiCategory(
        id: _asInt(j['category_id']),
        name: j['category_name']?.toString() ?? '',
        subcategories: (j['subcategories'] as List<dynamic>? ?? [])
            .map((s) => ApiSubcategory.fromJson(s as Map<String, dynamic>))
            .toList(),
      );

  /// Find subcategory by name.
  ApiSubcategory? findSubcategory(String name) {
    try {
      return subcategories.firstWhere((s) => s.name == name);
    } catch (_) {
      return null;
    }
  }
}

int _asInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}
