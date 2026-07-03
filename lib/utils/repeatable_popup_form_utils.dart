import '../models/api/api_models.dart';

String getRepeatableDisplayLabel(ApiField field) {
  final label = field.label;
  final index = field.index;
  if (index == null) return label;
  return '$label $index';
}

bool isDeletedRepeatableField(DynamicFieldModel field) =>
    field.field.isDeleted == true;

Iterable<DynamicFieldModel> visibleRepeatableFields(
  Iterable<DynamicFieldModel> fields,
) {
  return fields.where((field) => !isDeletedRepeatableField(field));
}

int nextRepeatableIndex(Iterable<DynamicFieldModel> fields) {
  final indexes = visibleRepeatableFields(fields)
      .map((field) => field.field.index)
      .whereType<int>();
  var maxIndex = -1;
  for (final index in indexes) {
    if (index > maxIndex) maxIndex = index;
  }
  return maxIndex + 1;
}

ApiField cloneApiFieldForRepeatable(ApiField source, int newIndex) {
  return source.copyWith(
    index: newIndex,
    isDeleted: false,
    subFields: source.subFields
        .map((field) => cloneApiFieldForRepeatable(field, newIndex))
        .toList(),
  );
}

DynamicFieldModel cloneFieldForRepeatable(
  DynamicFieldModel source,
  int newIndex,
) {
  final clonedField = cloneApiFieldForRepeatable(source.field, newIndex);
  final sourceChildren = source.value is List<DynamicFieldModel>
      ? source.value as List<DynamicFieldModel>
      : null;
  final clonedChildren = sourceChildren != null
      ? sourceChildren
          .map((field) => cloneFieldForRepeatable(field, newIndex))
          .toList()
      : clonedField.subFields
          .map((field) => _emptyDynamicFieldForRepeatable(field, newIndex))
          .toList();

  return DynamicFieldModel(
    field: clonedField,
    value: clonedField.isFormContainer ? clonedChildren : null,
    previewUrl: null,
    resolvedOptions: clonedField.options,
  );
}

DynamicFieldModel emptyDynamicFieldForRepeatableTemplate(
  ApiField source,
  int newIndex,
) {
  return _emptyDynamicFieldForRepeatable(source, newIndex);
}

DynamicFieldModel _emptyDynamicFieldForRepeatable(
  ApiField source,
  int newIndex,
) {
  final clonedField = cloneApiFieldForRepeatable(source, newIndex);
  return DynamicFieldModel(
    field: clonedField,
    value: clonedField.isFormContainer
        ? clonedField.subFields
            .map((field) => _emptyDynamicFieldForRepeatable(field, newIndex))
            .toList()
        : null,
    previewUrl: null,
    resolvedOptions: clonedField.options,
  );
}
