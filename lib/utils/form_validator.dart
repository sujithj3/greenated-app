import '../models/api/api_models.dart';
import 'field_fill_state.dart';

/// Result of a recursive form validation pass.
class ValidationResult {
  const ValidationResult({
    required this.isValid,
    this.firstInvalidLabel,
  });

  /// True when every required visible field has a value.
  final bool isValid;

  /// Human-readable label of the first required field that failed.
  final String? firstInvalidLabel;
}

// ─── Public API ──────────────────────────────────────────────────────────────

/// Validates a flat list of [DynamicFieldModel]s, recursing into any
/// `POPUP_FORM` children.
///
/// * [fields] – the top-level (or sibling-level) field list.
/// * [textValues] – text controller values keyed by field key (top-level only).
///
/// During traversal every popup-form field whose children contain at least one
/// invalid required child will have its [DynamicFieldModel.hasError] set to
/// `true` and [DynamicFieldModel.errorMessage] set to `"Missing required fields"`.
///
/// Returns a [ValidationResult] with the aggregate validity and the label of
/// the first failing required field (for a snack-bar message).
ValidationResult validateFields(
  List<DynamicFieldModel> fields, {
  Map<String, String>? textValues,
}) {
  String? firstInvalid;

  for (final df in fields) {
    // Skip hidden fields — they are not required to be filled.
    if (!shouldShowField(df, fields)) {
      df.clearError();
      continue;
    }

    final result =
        _validateSingleField(df, textValues: textValues, siblings: fields);

    if (!result.isValid && firstInvalid == null) {
      firstInvalid = result.firstInvalidLabel;
    }
  }

  return ValidationResult(
    isValid: firstInvalid == null,
    firstInvalidLabel: firstInvalid,
  );
}

// ─── Internal helpers ────────────────────────────────────────────────────────

/// Validates a single field.  For `POPUP_FORM` fields this recurses into the
/// child list.  Sets [DynamicFieldModel.hasError] / [errorMessage] on popup
/// parents as a side-effect.
ValidationResult _validateSingleField(
  DynamicFieldModel df, {
  Map<String, String>? textValues,
  required List<DynamicFieldModel> siblings,
}) {
  final f = df.field;

  // ── POPUP_FORM → recurse ─────────────────────────────────────────────────
  if (f.isPopupForm) {
    final children = df.value as List<DynamicFieldModel>? ?? [];
    final childResult = _validatePopupChildren(children);

    // If the popup itself is required AND completely empty, that's invalid.
    if (f.required && children.isEmpty) {
      df.setError('Missing required fields');
      return ValidationResult(isValid: false, firstInvalidLabel: f.label);
    }

    if (!childResult.isValid) {
      df.setError('Missing required fields');
      return childResult;
    }

    // Also check: popup required but no child has data at all
    if (f.required) {
      final hasAnyData = children
          .where((c) => shouldShowField(c, children))
          .any((c) => isFieldFilled(c, siblings: children));
      if (!hasAnyData) {
        df.setError('Missing required fields');
        return ValidationResult(isValid: false, firstInvalidLabel: f.label);
      }
    }

    df.clearError();
    return const ValidationResult(isValid: true);
  }

  // ── Scalar / non-popup field ─────────────────────────────────────────────
  if (!f.required) {
    df.clearError();
    return const ValidationResult(isValid: true);
  }

  dynamic v;
  if (textValues != null && textValues.containsKey(f.key)) {
    v = textValues[f.key]!.trim();
    if ((v as String).isEmpty) v = null;
  } else {
    v = df.value;
  }

  if (_isValueEmpty(v)) {
    df.setError('${f.label} is required');
    return ValidationResult(isValid: false, firstInvalidLabel: f.label);
  }

  df.clearError();
  return const ValidationResult(isValid: true);
}

/// Recursively validates all visible required children inside a popup form.
ValidationResult _validatePopupChildren(List<DynamicFieldModel> children) {
  String? firstInvalid;

  for (final child in children) {
    if (!shouldShowField(child, children)) {
      child.clearError();
      continue;
    }

    final result = _validateSingleField(
      child,
      siblings: children,
    );

    if (!result.isValid && firstInvalid == null) {
      firstInvalid = result.firstInvalidLabel;
    }
  }

  return ValidationResult(
    isValid: firstInvalid == null,
    firstInvalidLabel: firstInvalid,
  );
}

/// Returns true when [v] should be considered "empty" for required-field
/// validation.
bool _isValueEmpty(dynamic v) {
  if (v == null) return true;
  if (v is String && v.trim().isEmpty) return true;
  if (v is List && v.isEmpty) return true;
  return false;
}
