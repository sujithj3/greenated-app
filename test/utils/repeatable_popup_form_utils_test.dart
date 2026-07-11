import 'package:flutter_test/flutter_test.dart';
import 'package:greenated/models/api/api_models.dart';
import 'package:greenated/utils/field_fill_state.dart';
import 'package:greenated/utils/form_validator.dart';
import 'package:greenated/utils/repeatable_popup_form_utils.dart';

void main() {
  group('REPEATABLE_POPUP_FORM model support', () {
    test('parses and serializes style, index, and isDeleted metadata', () {
      final model = DynamicFieldModel.fromJson(<String, dynamic>{
        'fieldId': 100,
        'label': 'Temperature Readings',
        'key': 'temperature_readings',
        'type': 'form',
        'style': 'REPEATABLE_POPUP_FORM',
        'required': false,
        'value': null,
        'fields': [
          <String, dynamic>{
            'index': 0,
            'isDeleted': false,
            'fieldId': 101,
            'label': 'Temperature',
            'key': 'temperature',
            'type': 'number',
            'style': 'NUMBER',
            'required': true,
            'value': 26,
          },
        ],
      });

      expect(model.field.fieldStyle, FieldStyle.repeatablePopupForm);
      expect(model.field.isPopupForm, isFalse);
      expect(model.field.isFormContainer, isTrue);

      final children = model.value as List<DynamicFieldModel>;
      expect(children.single.field.index, 0);
      expect(children.single.field.isDeleted, isFalse);

      final json = model.toJson();
      expect(json['style'], 'REPEATABLE_POPUP_FORM');
      expect(json['fields'], isA<List<dynamic>>());
      final childJson = (json['fields'] as List<dynamic>).single as Map;
      expect(childJson['index'], 0);
      expect(childJson['isDeleted'], isFalse);
      expect(childJson['value'], 26);
    });
  });

  group('repeatable popup helpers', () {
    test('builds display labels without mutating the source label', () {
      const field = ApiField(
        fieldId: 1,
        label: 'Day',
        key: 'day',
        fieldType: FieldType.string,
        fieldStyle: FieldStyle.text,
        required: false,
        index: 2,
      );

      expect(getRepeatableDisplayLabel(field), 'Day 2');
      expect(field.label, 'Day');
    });

    test('calculates next index from visible non-deleted items only', () {
      final fields = <DynamicFieldModel>[
        DynamicFieldModel(
          field: _field(index: 0),
          value: 'a',
        ),
        DynamicFieldModel(
          field: _field(index: 7, isDeleted: true),
          value: 'deleted',
        ),
        DynamicFieldModel(
          field: _field(index: 2),
          value: 'b',
        ),
      ];

      expect(nextRepeatableIndex(fields), 3);
    });

    test('deep clone clears values and applies the new index recursively', () {
      final child = _field(
        fieldId: 3,
        label: 'Attachment',
        key: 'attachment',
        style: FieldStyle.file,
        index: 0,
      );
      final group = DynamicFieldModel(
        field: _field(
          fieldId: 2,
          label: 'Day',
          key: 'day',
          style: FieldStyle.popupForm,
          index: 0,
          subFields: [child],
        ),
        value: [
          DynamicFieldModel(
            field: child,
            value: ['remote/path.jpg'],
            previewUrl: ['https://example.com/path.jpg'],
          ),
        ],
      );

      final clone = cloneFieldForRepeatable(group, 1);
      final cloneChildren = clone.value as List<DynamicFieldModel>;

      expect(clone.field.label, 'Day');
      expect(clone.field.index, 1);
      expect(clone.field.isDeleted, isFalse);
      expect(cloneChildren.single.field.index, 1);
      expect(cloneChildren.single.field.isDeleted, isFalse);
      expect(cloneChildren.single.value, isNull);
      expect(cloneChildren.single.previewUrl, isNull);
    });

    test('validation and fill counts skip deleted required repeatable fields',
        () {
      final fields = <DynamicFieldModel>[
        DynamicFieldModel(
          field: _field(required: true, index: 0, isDeleted: true),
          value: null,
        ),
        DynamicFieldModel(
          field: _field(fieldId: 2, key: 'temperature_2', index: 1),
          value: '28',
        ),
      ];

      final validation = validateFields(fields);

      expect(validation.isValid, isTrue);
      expect(getTotalCount(fields), 1);
      expect(getFilledCount(fields), 1);
    });

    test('required repeatable parent allows existing deleted edit rows', () {
      final deletedChild = DynamicFieldModel(
        field: _field(required: true, index: 0, isDeleted: true),
        value: null,
      );
      final parent = DynamicFieldModel(
        field: _field(
          fieldId: 10,
          label: 'Readings',
          key: 'readings',
          style: FieldStyle.repeatablePopupForm,
          required: true,
          subFields: [deletedChild.field],
        ),
        value: [deletedChild],
      );

      final validation = validateFields([parent]);

      expect(validation.isValid, isTrue);
      expect(getTotalCount(parent.value as List<DynamicFieldModel>), 0);
    });
  });
}

ApiField _field({
  int fieldId = 1,
  String label = 'Temperature',
  String key = 'temperature',
  FieldStyle style = FieldStyle.text,
  bool required = false,
  int? index,
  bool? isDeleted,
  List<ApiField> subFields = const [],
}) {
  return ApiField(
    fieldId: fieldId,
    label: label,
    key: key,
    fieldType:
        style == FieldStyle.number ? FieldType.integer : FieldType.string,
    fieldStyle: style,
    required: required,
    index: index,
    isDeleted: isDeleted,
    subFields: subFields,
  );
}
