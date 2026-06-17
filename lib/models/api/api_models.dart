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
    this.placeHolder,
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
  final String? placeHolder;
  final List<ApiOption> options;
  final List<ApiField> subFields;
  final String? dependsOn;
  final FieldDataSource? dataSource;
  final List<dynamic>? showWhen;

  bool get isPopupForm => fieldStyle == FieldStyle.popupForm;

  /// Returns [placeHolder] if non-null and non-empty, otherwise falls back to [label].
  String get effectiveplaceHolder =>
      (placeHolder != null && placeHolder!.isNotEmpty) ? placeHolder! : label;

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
      placeHolder: data['placeHolder'] as String?,
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
      if (placeHolder != null) 'placeHolder': placeHolder,
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

  /// Presigned S3 URL(s) for display.
  /// Camera fields use a single string; FILE fields use a cleaned `List<String>`.
  /// Display-only — never included in form submissions (excluded from toJson).
  dynamic previewUrl;

  List<ApiOption> resolvedOptions;
  bool isLoadingOptions;
  String? optionsError;

  /// Validation error state – set by the recursive validator, read by the UI.
  /// Display-only — excluded from toJson / copyWith.
  bool hasError = false;
  String? errorMessage;

  void setError(String msg) {
    hasError = true;
    errorMessage = msg;
  }

  void clearError() {
    hasError = false;
    errorMessage = null;
  }

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
    } else if (field.fieldStyle == FieldStyle.file) {
      initialValue = <String>[];
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
      if (apiField.fieldStyle == FieldStyle.file) {
        resolvedValue = cleanStringList(resolvedValue);
      } else if (resolvedValue is List) {
        resolvedValue = List<dynamic>.from(resolvedValue);
      }
    }

    return DynamicFieldModel(
      field: apiField,
      value: resolvedValue,
      previewUrl: apiField.fieldStyle == FieldStyle.file
          ? cleanStringList(data['previewUrl'])
          : _firstCleanString(data['previewUrl']),
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
      json['value'] =
          field.fieldStyle == FieldStyle.file ? fileValueList : value;
    }
    return json;
  }

  DynamicFieldModel copyWith({
    ApiField? field,
    dynamic value,
    dynamic previewUrl,
  }) {
    return DynamicFieldModel(
      field: field ?? this.field,
      value: value ?? _copyDynamicValue(this.value),
      previewUrl: previewUrl ?? _copyDynamicValue(this.previewUrl),
      resolvedOptions: resolvedOptions,
    );
  }

  List<String> get fileValueList => cleanStringList(value);

  List<String> get filePreviewUrlList => cleanStringList(previewUrl);

  List<AppFileItem> get fileItems => AppFileItem.fromReferences(
        value: value,
        previewUrl: previewUrl,
      );

  void appendFileReferences({
    required List<String> paths,
    required List<String> previewUrls,
  }) {
    value = <String>[
      ...fileValueList,
      ...cleanStringList(paths),
    ];
    previewUrl = <String>[
      ...filePreviewUrlList,
      ...cleanStringList(previewUrls),
    ];
  }

  bool removeFileReferenceByPath(String path) {
    final trimmedPath = path.trim();
    if (trimmedPath.isEmpty) return false;

    final paths = fileValueList;
    final previews = filePreviewUrlList;
    final index = paths.indexWhere((item) => item.trim() == trimmedPath);
    if (index == -1) return false;

    paths.removeAt(index);
    if (index < previews.length) {
      previews.removeAt(index);
    }
    value = paths;
    previewUrl = previews;
    return true;
  }
}

class AppFileItem {
  const AppFileItem({
    this.id,
    this.name,
    this.url,
    this.localPath,
    this.remotePath,
    this.mimeType,
    this.extension,
    required this.isRemote,
  });

  final String? id;
  final String? name;
  final String? url;
  final String? localPath;
  final String? remotePath;
  final String? mimeType;
  final String? extension;
  final bool isRemote;

  factory AppFileItem.remote({
    String? path,
    String? previewUrl,
  }) {
    final source = _firstNonEmptyString(<String?>[path, previewUrl]);
    return AppFileItem(
      id: path ?? previewUrl,
      name: _fileNameFrom(source),
      url: previewUrl?.trim().isNotEmpty == true
          ? previewUrl!.trim()
          : (path != null && _isHttpUrl(path) ? path.trim() : null),
      remotePath: path?.trim().isNotEmpty == true ? path!.trim() : null,
      extension: _extensionFrom(source),
      isRemote: true,
    );
  }

  factory AppFileItem.local(String path) {
    return AppFileItem(
      id: path,
      name: _fileNameFrom(path),
      localPath: path,
      remotePath: null,
      extension: _extensionFrom(path),
      isRemote: false,
    );
  }

  static List<AppFileItem> fromReferences({
    required Object? value,
    required Object? previewUrl,
  }) {
    final paths = cleanStringList(value);
    final previews = cleanStringList(previewUrl);
    final total =
        paths.length > previews.length ? paths.length : previews.length;
    final files = <AppFileItem>[];
    for (var i = 0; i < total; i++) {
      final path = i < paths.length ? paths[i] : null;
      final preview = i < previews.length ? previews[i] : null;
      if ((path == null || path.trim().isEmpty) &&
          (preview == null || preview.trim().isEmpty)) {
        continue;
      }
      files.add(AppFileItem.remote(path: path, previewUrl: preview));
    }
    return files;
  }

  String get displayName {
    final candidate = _firstNonEmptyString(<String?>[
      name,
      localPath,
      id,
      url,
    ]);
    return _fileNameFrom(candidate) ?? 'File';
  }

  bool get isImage => const <String>{
        'jpg',
        'jpeg',
        'png',
        'gif',
        'webp',
        'bmp',
        'heic',
        'heif',
      }.contains(_normalizedExtension);

  bool get isPdf => _normalizedExtension == 'pdf';

  bool get isDoc => _normalizedExtension == 'doc';

  bool get isDocx => _normalizedExtension == 'docx';

  bool get isTxt => _normalizedExtension == 'txt';

  bool get isPreviewable => isImage || isPdf || isTxt;

  String get _normalizedExtension =>
      (extension ?? _extensionFrom(localPath ?? url ?? id) ?? '').toLowerCase();
}

class FarmerDetails {
  const FarmerDetails({
    this.farmerId,
    this.farmerCode,
    this.fields = const [],
  });

  final int? farmerId;
  final String? farmerCode;
  final List<DynamicFieldModel> fields;

  factory FarmerDetails.fromJson(Map<String, dynamic> json) {
    final data = _normalizeJsonKeys(json);
    final rawFields = data['fields'] as List<dynamic>? ?? const [];
    return FarmerDetails(
      farmerId: data['farmerId'] == null ? null : _asInt(data['farmerId']),
      farmerCode: _asNullableString(data['farmerCode']),
      fields: rawFields
          .whereType<Map>()
          .map((field) =>
              DynamicFieldModel.fromJson(Map<String, dynamic>.from(field)))
          .toList(),
    );
  }
}

class LandDetail {
  const LandDetail({
    this.submissionId,
    this.landId,
    this.landCode,
    this.landTitle,
    this.fields = const [],
  });

  final int? submissionId;
  final int? landId;
  final String? landCode;
  final String? landTitle;
  final List<DynamicFieldModel> fields;

  factory LandDetail.fromJson(Map<String, dynamic> json) {
    final data = _normalizeJsonKeys(json);
    final rawFields = data['fields'] as List<dynamic>? ?? const [];
    return LandDetail(
      submissionId:
          data['submissionId'] == null ? null : _asInt(data['submissionId']),
      landId: data['landId'] == null ? null : _asInt(data['landId']),
      landCode: _asNullableString(data['landCode']),
      landTitle: _asNullableString(data['landTitle']),
      fields: rawFields
          .whereType<Map>()
          .map((field) =>
              DynamicFieldModel.fromJson(Map<String, dynamic>.from(field)))
          .toList(),
    );
  }
}

class ApiForm {
  const ApiForm({
    required this.formId,
    required this.formName,
    this.prefixCode,
    this.formType,
    this.description,
    this.isActive,
    this.geoLocationRequired = false,
    this.fields = const [],
  });

  final int formId;
  final String formName;
  final String? prefixCode;
  final String? formType;
  final String? description;
  final bool? isActive;
  final bool geoLocationRequired;
  final List<ApiField> fields;

  factory ApiForm.fromJson(Map<String, dynamic> json) {
    final data = _normalizeJsonKeys(json);
    return ApiForm(
      formId: _asInt(data['formId']),
      formName: data['formName']?.toString() ?? '',
      prefixCode: _asNullableString(data['prefixCode']),
      formType: _asNullableString(data['formType']),
      description: _asNullableString(data['description']),
      isActive: data.containsKey('isActive') ? _asBool(data['isActive']) : null,
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
        if (prefixCode != null) 'prefixCode': prefixCode,
        if (formType != null) 'formType': formType,
        if (description != null) 'description': description,
        if (isActive != null) 'isActive': isActive,
        'geoLocationRequired': geoLocationRequired,
        'fields': fields.map((field) => field.toJson()).toList(),
      };
}

class LandFormData {
  const LandFormData({
    required this.subcategoryId,
    required this.subcategoryName,
    required this.rawData,
    this.forms = const [],
  });

  final int subcategoryId;
  final String subcategoryName;
  final Map<String, dynamic> rawData;
  final List<ApiForm> forms;

  factory LandFormData.fromJson(Map<String, dynamic> json) {
    final data = _normalizeJsonKeys(json);
    return LandFormData(
      subcategoryId: _asInt(data['subcategoryId']),
      subcategoryName: data['subcategoryName']?.toString() ?? '',
      rawData: _deepCopyMap(json),
      forms: (data['forms'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((json) => ApiForm.fromJson(Map<String, dynamic>.from(json)))
          .toList(),
    );
  }

  ApiForm? get firstUsableForm {
    final activeForms = forms.where((form) => form.isActive == true).toList();
    if (activeForms.isNotEmpty) {
      for (final form in activeForms) {
        if (form.fields.isNotEmpty) return form;
      }
      return null;
    }
    for (final form in forms) {
      if (form.fields.isNotEmpty) return form;
    }
    return null;
  }

  Map<String, dynamic> copyRawData() => _deepCopyMap(rawData);

  Map<String, dynamic> toJson() => copyRawData();
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

bool _asBool(Object? value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
  }
  return fallback;
}

Map<String, dynamic> _deepCopyMap(Map<dynamic, dynamic> source) {
  return source.map(
    (key, value) => MapEntry(key.toString(), _deepCopyJsonValue(value)),
  );
}

Object? _deepCopyJsonValue(Object? value) {
  if (value is Map) return _deepCopyMap(value);
  if (value is List) return value.map(_deepCopyJsonValue).toList();
  return value;
}

String? _asNullableString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

List<String> cleanStringList(Object? raw) {
  if (raw == null) return <String>[];
  if (raw is List) {
    return raw
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
  }
  final text = raw.toString().trim();
  return text.isEmpty ? <String>[] : <String>[text];
}

String? _firstCleanString(Object? raw) {
  final values = cleanStringList(raw);
  return values.isEmpty ? null : values.first;
}

dynamic _copyDynamicValue(dynamic value) {
  if (value is List<DynamicFieldModel>) {
    return value.map((field) => field.copyWith()).toList();
  }
  if (value is List) {
    return List<dynamic>.from(value);
  }
  if (value is Map) {
    return Map<dynamic, dynamic>.from(value);
  }
  return value;
}

String? _firstNonEmptyString(List<String?> values) {
  for (final value in values) {
    final text = value?.trim();
    if (text != null && text.isNotEmpty) return text;
  }
  return null;
}

bool _isHttpUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
}

String? _fileNameFrom(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  final withoutQuery = value.split('?').first.split('#').first;
  final normalized = withoutQuery.replaceAll(r'\', '/');
  final segments = normalized.split('/').where((part) => part.isNotEmpty);
  if (segments.isEmpty) return value;
  final last = Uri.decodeComponent(segments.last);
  return last.isEmpty ? value : last;
}

String? _extensionFrom(String? raw) {
  final fileName = _fileNameFrom(raw);
  if (fileName == null) return null;
  final dotIndex = fileName.lastIndexOf('.');
  if (dotIndex < 0 || dotIndex == fileName.length - 1) return null;
  return fileName.substring(dotIndex + 1).toLowerCase();
}

List<dynamic>? _parseShowWhen(Object? raw) {
  if (raw == null) return null;
  if (raw is List) return List<dynamic>.from(raw);
  final parsed = int.tryParse(raw.toString());
  return [parsed ?? raw];
}

/// Converts a date string from YYYY-MM-DD to DD-MM-YYYY format.
/// Returns the original string if it doesn't match YYYY-MM-DD.
String formatDateForDisplay(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) return value;
  return '${match.group(3)}-${match.group(2)}-${match.group(1)}';
}

/// Returns true if [field] should be visible given the current [allFields].
///
/// A field is visible when it has no visibility condition, or when its parent's
/// current value is contained in the field's showWhen list.
bool shouldShowField(
    DynamicFieldModel field, List<DynamicFieldModel> allFields) {
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
