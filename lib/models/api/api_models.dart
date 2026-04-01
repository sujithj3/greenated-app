library;

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
      'NUMBER' => FieldType.integer,
      _ => FieldType.unknown,
    };
  }
}

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
  mapPolygon,
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
      'BUTTON' => FieldStyle.popupForm,
      'MAP_POLYGON' => FieldStyle.mapPolygon,
      _ => FieldStyle.unknown,
    };
  }
}

class ApiOption {
  const ApiOption({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  factory ApiOption.fromJson(Map<String, dynamic> json) {
    final data = _normalizeJsonKeys(json);
    final rawName = data['name'] ?? data['label'] ?? data['value'];
    final String name = rawName?.toString() ?? '';
    final rawId = data['id'] ?? data['optionId'] ?? data['value'];
    return ApiOption(
      id: _asInt(rawId, fallback: name.hashCode),
      name: name,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
      };
}

class FieldDataSource {
  const FieldDataSource({
    required this.type,
    required this.endpoint,
    required this.method,
    this.params = const {},
  });

  final String type;
  final String endpoint;
  final String method;
  final Map<String, String> params;

  factory FieldDataSource.fromJson(Map<String, dynamic> json) {
    final data = _normalizeJsonKeys(json);
    String ep = data['endpoint']?.toString() ?? '';
    if (ep.startsWith('/')) ep = ep.substring(1);

    return FieldDataSource(
      type: data['type']?.toString() ?? 'API',
      endpoint: ep,
      method: (data['method']?.toString() ?? 'GET').toUpperCase(),
      params: (data['params'] as Map?)
              ?.map((k, v) => MapEntry(k.toString(), v.toString())) ??
          const {},
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type,
        'endpoint': endpoint,
        'method': method,
        'params': params,
      };
}

class ApiField {
  const ApiField({
    required this.fieldId,
    required this.label,
    required this.key,
    required this.fieldType,
    required this.fieldStyle,
    required this.required,
    this.options = const [],
    this.subFields = const [],
    this.dependsOn,
    this.dataSource,
    this.showWhen,
  });

  final int fieldId;
  final String label;
  final String key;
  final FieldType fieldType;
  final FieldStyle fieldStyle;
  final bool required;
  final List<ApiOption> options;
  final List<ApiField> subFields;
  final String? dependsOn;
  final FieldDataSource? dataSource;
  final List<dynamic>? showWhen;

  bool get isPopupForm => fieldStyle == FieldStyle.popupForm;

  /// True when this field uses local visibility (dependsOn + showWhen, no dataSource).
  bool get hasVisibilityCondition =>
      dependsOn != null && showWhen != null && dataSource == null;

  List<String> get fieldData => options.map((option) => option.name).toList();

  factory ApiField.fromJson(Map<String, dynamic> json) {
    final data = _normalizeJsonKeys(json);
    final resolvedFieldType = FieldType.fromApiValue(data['type']);
    final resolvedFieldStyle = FieldStyle.fromApiValue(data['style']);
    final rawOptions = data['options'] as List<dynamic>? ?? const [];

    List<ApiOption> options = const [];
    List<ApiField> subFields = const [];

    if (resolvedFieldStyle == FieldStyle.popupForm) {
      final rawNested = data['fields'] as List<dynamic>? ?? rawOptions;
      subFields = rawNested
          .whereType<Map>()
          .map((json) => ApiField.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } else {
      options = rawOptions
          .whereType<Map>()
          .map((json) => ApiOption.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    }

    return ApiField(
      fieldId: _asInt(data['fieldId']),
      label: data['label']?.toString() ?? '',
      key: data['key']?.toString() ?? '',
      fieldType: resolvedFieldType,
      fieldStyle: resolvedFieldStyle,
      required: data['required'] as bool? ?? false,
      options: options,
      subFields: subFields,
      dependsOn: data['dependsOn']?.toString(),
      dataSource: data['dataSource'] is Map
          ? FieldDataSource.fromJson(
              Map<String, dynamic>.from(data['dataSource'] as Map))
          : null,
      showWhen: _parseShowWhen(data['showWhen']),
    );
  }

  Map<String, dynamic> toJson() {
    final typeValue = switch (fieldType) {
      FieldType.string => 'STRING',
      FieldType.integer => 'INT',
      FieldType.decimal => 'DOUBLE',
      FieldType.boolean => 'BOOL',
      FieldType.arrayString => 'ARRAY_STRING',
      FieldType.arrayInt => 'ARRAY_INT',
      FieldType.arrayDict => 'ARRAY_DICT',
      FieldType.dict => 'DICT',
      FieldType.image => 'IMAGE',
      FieldType.multimedia => 'MULTIMEDIA',
      FieldType.unknown => 'UNKNOWN',
    };

    final styleValue = switch (fieldStyle) {
      FieldStyle.text => 'TEXT',
      FieldStyle.number => 'NUMBER',
      FieldStyle.dropdown => 'DROPDOWN',
      FieldStyle.checkbox => 'CHECKBOX',
      FieldStyle.radio => 'RADIO',
      FieldStyle.date => 'DATE',
      FieldStyle.camera => 'CAMERA',
      FieldStyle.file => 'FILE',
      FieldStyle.cameraFile => 'CAMERA_FILE',
      FieldStyle.popupForm => 'POPUP_FORM',
      FieldStyle.mapPolygon => 'MAP_POLYGON',
      FieldStyle.unknown => 'UNKNOWN',
    };

    return <String, dynamic>{
      'fieldId': fieldId,
      'label': label,
      'key': key,
      'type': typeValue,
      'style': styleValue,
      'required': required,
      'options': isPopupForm
          ? subFields.map((field) => field.toJson()).toList()
          : options.map((option) => option.toJson()).toList(),
      if (dependsOn != null) 'dependsOn': dependsOn,
      if (dataSource != null) 'dataSource': dataSource!.toJson(),
      if (showWhen != null) 'showWhen': showWhen,
    };
  }
}

class DynamicFieldModel {
  DynamicFieldModel({
    required this.field,
    this.value,
    this.previewUrl,
    List<ApiOption>? resolvedOptions,
    this.isLoadingOptions = false,
    this.optionsError,
  }) : resolvedOptions = resolvedOptions ?? field.options;

  final ApiField field;
  dynamic value;

  /// Presigned S3 URL for displaying camera-field images in the UI.
  /// Display-only — never included in form submissions (excluded from toJson).
  String? previewUrl;

  List<ApiOption> resolvedOptions;
  bool isLoadingOptions;
  String? optionsError;

  int _fetchGeneration = 0;
  int get fetchGeneration => _fetchGeneration;
  void incrementFetchGeneration() => _fetchGeneration++;

  factory DynamicFieldModel.fromApiField(ApiField field) {
    dynamic initialValue;
    if (field.isPopupForm) {
      initialValue = field.subFields
          .map((subField) => DynamicFieldModel.fromApiField(subField))
          .toList();
    } else if (field.fieldStyle == FieldStyle.checkbox) {
      initialValue = false;
    }
    return DynamicFieldModel(
      field: field,
      value: initialValue,
      resolvedOptions: field.options,
    );
  }

  factory DynamicFieldModel.fromJson(Map<String, dynamic> json) {
    final data = _normalizeJsonKeys(json);
    final apiField = ApiField.fromJson(data);
    dynamic resolvedValue;

    if (apiField.isPopupForm) {
      final rawFields = data['fields'] as List<dynamic>? ?? const [];
      resolvedValue = rawFields
          .whereType<Map>()
          .map(
            (json) =>
                DynamicFieldModel.fromJson(Map<String, dynamic>.from(json)),
          )
          .toList();
    } else {
      resolvedValue = data['value'];
      if (resolvedValue is List) {
        resolvedValue = List<dynamic>.from(resolvedValue);
      }
    }

    return DynamicFieldModel(
      field: apiField,
      value: resolvedValue,
      previewUrl: data['previewUrl'] as String?,
      resolvedOptions: apiField.options,
    );
  }

  Map<String, dynamic> toJson() {
    final json = field.toJson();
    if (field.isPopupForm) {
      json.remove('options');
      if (value is List<DynamicFieldModel>) {
        json['fields'] = (value as List<DynamicFieldModel>)
            .map((field) => field.toJson())
            .toList();
      } else {
        json['fields'] = <Map<String, dynamic>>[];
      }
    } else {
      json['value'] = value;
    }
    return json;
  }

  DynamicFieldModel copyWith({
    ApiField? field,
    dynamic value,
    String? previewUrl,
  }) {
    return DynamicFieldModel(
      field: field ?? this.field,
      value: value ?? this.value,
      previewUrl: previewUrl ?? this.previewUrl,
      resolvedOptions: resolvedOptions,
    );
  }
}

class ApiForm {
  const ApiForm({
    required this.formId,
    required this.formName,
    this.geoLocationRequired = false,
    this.fields = const [],
  });

  final int formId;
  final String formName;
  final bool geoLocationRequired;
  final List<ApiField> fields;

  factory ApiForm.fromJson(Map<String, dynamic> json) {
    final data = _normalizeJsonKeys(json);
    return ApiForm(
      formId: _asInt(data['formId']),
      formName: data['formName']?.toString() ?? '',
      geoLocationRequired: data['geoLocationRequired'] as bool? ?? false,
      fields: (data['fields'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((json) => ApiField.fromJson(Map<String, dynamic>.from(json)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'formId': formId,
        'formName': formName,
        'geoLocationRequired': geoLocationRequired,
        'fields': fields.map((field) => field.toJson()).toList(),
      };
}

Map<String, dynamic> _normalizeJsonKeys(Map<String, dynamic> json) {
  final normalized = <String, dynamic>{};
  json.forEach((key, value) {
    normalized[_toCamelCase(key)] = value;
  });
  return normalized;
}

String _toCamelCase(String input) {
  if (!input.contains('_')) return input;
  final segments = input.split('_');
  if (segments.isEmpty) return input;
  return segments.first +
      segments
          .skip(1)
          .where((segment) => segment.isNotEmpty)
          .map(
            (segment) => '${segment[0].toUpperCase()}${segment.substring(1)}',
          )
          .join();
}

int _asInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

List<dynamic>? _parseShowWhen(Object? raw) {
  if (raw == null) return null;
  if (raw is List) return List<dynamic>.from(raw);
  final parsed = int.tryParse(raw.toString());
  return [parsed ?? raw];
}

/// Returns true if [field] should be visible given the current [allFields].
///
/// A field is visible when it has no visibility condition, or when its parent's
/// current value is contained in the field's showWhen list.
bool shouldShowField(DynamicFieldModel field, List<DynamicFieldModel> allFields) {
  final apiField = field.field;
  if (!apiField.hasVisibilityCondition) return true;

  final parentIdx =
      allFields.indexWhere((df) => df.field.key == apiField.dependsOn);
  if (parentIdx == -1) return true;

  final parentValue = allFields[parentIdx].value;
  if (parentValue == null) return false;

  return apiField.showWhen!
      .any((allowed) => allowed.toString() == parentValue.toString());
}
