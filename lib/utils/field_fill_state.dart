import '../models/api/api_models.dart';

/// Determines whether a single [DynamicFieldModel] contains meaningful
/// user-entered data.
///
/// For POPUP_FORM fields the evaluation is recursive: the popup is considered
/// filled only when at least one *visible* child field has meaningful data.
/// This prevents false positives caused by the model layer eagerly initializing
/// popup children with non-null container objects.
///
/// [siblings] is the sibling list used to resolve visibility for nested popup
/// children. It is only needed when evaluating a field that is itself a popup
/// form (the popup's own children act as siblings to each other).
bool isFieldFilled(DynamicFieldModel field,
    {List<DynamicFieldModel>? siblings}) {
  final style = field.field.fieldStyle;
  final value = field.value;

  switch (style) {
    // ── Scalar text types ──────────────────────────────────────────────────
    case FieldStyle.text:
    case FieldStyle.number:
    case FieldStyle.date:
      if (value == null) return false;
      if (value is String) return value.trim().isNotEmpty;
      // A numeric 0 stored as int/double counts as filled (user explicitly
      // entered it).
      return true;

    // ── Dropdown ───────────────────────────────────────────────────────────
    case FieldStyle.dropdown:
      if (value == null) return false;
      final str = value.toString().trim();
      // "no_data" is a placeholder injected when options haven't loaded.
      if (str.isEmpty || str == 'no_data') return false;
      return true;

    // ── Checkbox ──────────────────────────────────────────────────────────
    case FieldStyle.checkbox:
      // false is the default initialization and should NOT count as filled.
      return value == true;

    // ── Radio ─────────────────────────────────────────────────────────────
    case FieldStyle.radio:
      if (value == null) return false;
      return value.toString().trim().isNotEmpty;

    // ── Camera / File ─────────────────────────────────────────────────────
    case FieldStyle.camera:
    case FieldStyle.file:
    case FieldStyle.cameraFile:
      if (value == null) return false;
      if (value is String) return value.trim().isNotEmpty;
      return true;

    // ── Map Polygon ───────────────────────────────────────────────────────
    case FieldStyle.mapPolygon:
      if (value == null) return false;
      if (value is List) return value.isNotEmpty;
      return false;

    // ── Popup Form (recursive) ────────────────────────────────────────────
    case FieldStyle.popupForm:
      if (value == null) return false;
      if (value is! List<DynamicFieldModel>) return false;
      final children = value;
      // A popup is filled when at least one *visible* child is filled.
      return children
          .where((child) => shouldShowField(child, children))
          .any((child) => isFieldFilled(child, siblings: children));

    // ── Unknown / unsupported ─────────────────────────────────────────────
    case FieldStyle.unknown:
      if (value == null) return false;
      if (value is String) return value.trim().isNotEmpty;
      if (value is List) return value.isNotEmpty;
      return true;
  }
}

/// Returns the number of *visible* fields in [fields] that are filled.
///
/// Only fields passing the [shouldShowField] visibility check are counted.
/// This keeps the progress indicator aligned with what the user sees in the
/// popup sheet.
int getFilledCount(List<DynamicFieldModel> fields) {
  return fields
      .where((f) => shouldShowField(f, fields))
      .where((f) => isFieldFilled(f, siblings: fields))
      .length;
}

/// Returns the number of *visible* fields in [fields].
///
/// Hidden conditional fields are excluded so they don't inflate the
/// denominator of the progress indicator.
int getTotalCount(List<DynamicFieldModel> fields) {
  return fields.where((f) => shouldShowField(f, fields)).length;
}
