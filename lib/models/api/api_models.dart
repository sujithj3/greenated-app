/// Models that match the backend API response for category form configuration.
///
/// API shape:
/// { statusCode, status, message, data: [ ApiCategory ] }
library;

// ─── FieldType (data type of a field) ─────────────────────────────────────────

enum FieldType {
  string,
  number,
  boolean,
  image,
  multimedia,
  unknown;

  static FieldType fromApiValue(Object? rawValue) {
    final value = (rawValue as String? ?? '').trim().toLowerCase();
    return switch (value) {
      'string' => FieldType.string,
      'number' => FieldType.number,
      'boolean' => FieldType.boolean,
      'image' => FieldType.image,
      'multimedia' => FieldType.multimedia,
      _ => FieldType.unknown,
    };
  }

  /// Infer from the legacy `type` field (TEXT, NUMBER, etc.)
  static FieldType fromLegacyType(String type) {
    return switch (type) {
      'TEXT' => FieldType.string,
      'NUMBER' => FieldType.number,
      'CHECKBOX' => FieldType.boolean,
      'CAMERA' => FieldType.image,
      'FILE' => FieldType.multimedia,
      _ => FieldType.string,
    };
  }
}

// ─── FieldStyle (UI rendering style) ──────────────────────────────────────────

enum FieldStyle {
  text,
  dropdown,
  checkbox,
  radio,
  date,
  camera,
  file,
  cameraFile,
  button,
  unknown;

  static FieldStyle fromApiValue(Object? rawValue) {
    final value = (rawValue as String? ?? '').trim().toLowerCase();
    return switch (value) {
      'text' => FieldStyle.text,
      'dropdown' => FieldStyle.dropdown,
      'checkbox' => FieldStyle.checkbox,
      'radio' => FieldStyle.radio,
      'date' => FieldStyle.date,
      'camera' => FieldStyle.camera,
      'file' => FieldStyle.file,
      'camera_file' => FieldStyle.cameraFile,
      'button' => FieldStyle.button,
      _ => FieldStyle.unknown,
    };
  }

  /// Infer from the legacy `type` field.
  static FieldStyle fromLegacyType(String type) {
    return switch (type) {
      'TEXT' => FieldStyle.text,
      'NUMBER' => FieldStyle.text,
      'DROPDOWN' => FieldStyle.dropdown,
      'CHECKBOX' => FieldStyle.checkbox,
      'RADIO' => FieldStyle.radio,
      'DATE' => FieldStyle.date,
      'CAMERA' => FieldStyle.camera,
      'FILE' => FieldStyle.file,
      'BUTTON' => FieldStyle.button,
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
  final String
      type; // Legacy: TEXT | NUMBER | DROPDOWN | BUTTON | CHECKBOX | RADIO | DATE | CAMERA | FILE
  final FieldType? _explicitFieldType;
  final FieldStyle? _explicitFieldStyle;
  final bool required;
  final List<ApiOption> options; // for DROPDOWN / RADIO
  final ApiPopup? popup; // for BUTTON

  /// Resolved data type.
  FieldType get fieldType =>
      _explicitFieldType ?? FieldType.fromLegacyType(type);

  /// Resolved UI rendering style.
  FieldStyle get fieldStyle =>
      _explicitFieldStyle ?? FieldStyle.fromLegacyType(type);

  /// Option names as plain strings (convenience for radio / dropdown).
  List<String> get fieldData => options.map((o) => o.name).toList();

  const ApiField({
    required this.fieldId,
    required this.label,
    required this.key,
    required this.type,
    FieldType? fieldType,
    FieldStyle? fieldStyle,
    required this.required,
    this.options = const [],
    this.popup,
  })  : _explicitFieldType = fieldType,
        _explicitFieldStyle = fieldStyle;

  factory ApiField.fromJson(Map<String, dynamic> j) {
    final type = (j['type'] as String? ?? 'TEXT').toUpperCase();
    return ApiField(
      fieldId: _asInt(j['field_id']),
      label: (j['label']?.toString() ?? ''),
      key: (j['key']?.toString() ?? ''),
      type: type,
      fieldType: j['field_type'] != null
          ? FieldType.fromApiValue(j['field_type'])
          : null,
      fieldStyle: j['field_style'] != null
          ? FieldStyle.fromApiValue(j['field_style'])
          : null,
      required: j['required'] as bool? ?? false,
      options: (j['options'] as List<dynamic>? ?? [])
          .map((o) => ApiOption.fromJson(o as Map<String, dynamic>))
          .toList(),
      popup: j['popup'] != null
          ? ApiPopup.fromJson(j['popup'] as Map<String, dynamic>)
          : null,
    );
  }
}

// ─── ApiPopup (inside BUTTON field) ──────────────────────────────────────────
class ApiPopup {
  final String title;
  final List<ApiField> fields;

  const ApiPopup({required this.title, required this.fields});

  factory ApiPopup.fromJson(Map<String, dynamic> j) => ApiPopup(
        title: j['popup_title'] as String,
        fields: (j['fields'] as List<dynamic>)
            .map((f) => ApiField.fromJson(f as Map<String, dynamic>))
            .toList(),
      );
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
