/// Models that match the backend API response for category form configuration.
///
/// API shape:
/// { statusCode, status, message, data: [ ApiCategory ] }

// ─── Option (inside DROPDOWN field) ─────────────────────────────────────────
class ApiOption {
  final int id;
  final String name;

  const ApiOption({required this.id, required this.name});

  factory ApiOption.fromJson(Map<String, dynamic> j) =>
      ApiOption(id: j['id'] as int, name: j['name'] as String);
}

// ─── ApiField ────────────────────────────────────────────────────────────────
class ApiField {
  final int fieldId;
  final String label;
  final String key;
  final String type;   // TEXT | NUMBER | DROPDOWN | BUTTON
  final bool required;
  final List<ApiOption> options; // only for DROPDOWN
  final ApiPopup? popup;         // only for BUTTON

  const ApiField({
    required this.fieldId,
    required this.label,
    required this.key,
    required this.type,
    required this.required,
    this.options = const [],
    this.popup,
  });

  factory ApiField.fromJson(Map<String, dynamic> j) => ApiField(
        fieldId:  j['field_id'] as int,
        label:    j['label'] as String,
        key:      j['key'] as String,
        type:     (j['type'] as String).toUpperCase(),
        required: j['required'] as bool? ?? false,
        options:  (j['options'] as List<dynamic>? ?? [])
            .map((o) => ApiOption.fromJson(o as Map<String, dynamic>))
            .toList(),
        popup: j['popup'] != null
            ? ApiPopup.fromJson(j['popup'] as Map<String, dynamic>)
            : null,
      );
}

// ─── ApiPopup (inside BUTTON field) ──────────────────────────────────────────
class ApiPopup {
  final String title;
  final List<ApiField> fields;

  const ApiPopup({required this.title, required this.fields});

  factory ApiPopup.fromJson(Map<String, dynamic> j) => ApiPopup(
        title:  j['popup_title'] as String,
        fields: (j['fields'] as List<dynamic>)
            .map((f) => ApiField.fromJson(f as Map<String, dynamic>))
            .toList(),
      );
}

// ─── ApiForm ─────────────────────────────────────────────────────────────────
class ApiForm {
  final int formId;
  final String formName;
  final List<ApiField> fields;

  const ApiForm({
    required this.formId,
    required this.formName,
    required this.fields,
  });

  factory ApiForm.fromJson(Map<String, dynamic> j) => ApiForm(
        formId:   j['form_id'] as int,
        formName: j['form_name'] as String,
        fields:   (j['fields'] as List<dynamic>)
            .map((f) => ApiField.fromJson(f as Map<String, dynamic>))
            .toList(),
      );
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
        id:    j['subcategory_id'] as int,
        name:  j['subcategory_name'] as String,
        forms: (j['forms'] as List<dynamic>)
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
        id:            j['category_id'] as int,
        name:          j['category_name'] as String,
        subcategories: (j['subcategories'] as List<dynamic>)
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
