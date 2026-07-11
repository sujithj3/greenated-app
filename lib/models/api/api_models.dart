/// Core data models for the app's **server-driven dynamic forms**.
///
/// The backend does not ship fixed screens; instead it describes each form as
/// JSON (categories → subcategories → forms → fields). This file is the
/// backbone that turns that JSON into typed Dart objects, holds the user's
/// runtime input, and serializes everything back for submission.
///
/// The model layer is organised in three tiers:
///
/// 1. **Field description (immutable):** [FieldType], [FieldStyle], [ApiOption],
///    [FieldDataSource] and [ApiField] describe *what* a field is — its data
///    type, how it renders, its selectable options and any conditional rules.
/// 2. **Runtime state (mutable):** [DynamicFieldModel] pairs an [ApiField] with
///    the value the user has entered, its resolved options and validation
///    state. This is the object the UI binds to and edits.
/// 3. **Aggregates:** [ApiForm], [FarmerDetails], [LandDetail] and
///    [LandFormData] group fields into complete forms and submissions;
///    [AppFileItem] models file/image attachments.
///
/// A set of tolerant JSON helpers at the bottom of the file (key normalisation,
/// safe int/bool parsing, deep copying, etc.) lets the models absorb backend
/// inconsistencies (snake_case vs camelCase, strings-for-numbers) without
/// crashing.
library;

/// Logical data type of a field's value, as declared by the backend.
///
/// This drives how a value is parsed, validated and serialized (e.g. an
/// [arrayString] is sent as a list, an [integer] as a number). It is distinct
/// from [FieldStyle], which only controls how the field is rendered.
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

  /// Maps the backend's raw type code to a [FieldType].
  ///
  /// Matching is case-insensitive and tolerant of both hyphen and underscore
  /// separators (e.g. `ARRAY-STRING` and `ARRAY_STRING`). Unrecognised values
  /// fall back to [FieldType.unknown] rather than throwing.
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

/// Visual/interaction style of a field — i.e. which widget renders it.
///
/// Where [FieldType] describes the data, [FieldStyle] describes the control:
/// a plain text box, a dropdown, a date picker, a camera capture, a file
/// picker, a nested pop-up form, a map polygon, etc.
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
  repeatablePopupForm,
  mapPolygon,
  unknown;

  /// Maps the backend's raw style code to a [FieldStyle].
  ///
  /// Case-insensitive; unrecognised values become [FieldStyle.unknown]. Note
  /// that the legacy `BUTTON` code is treated as a [popupForm].
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
      'REPEATABLE_POPUP_FORM' => FieldStyle.repeatablePopupForm,
      'MAP_POLYGON' => FieldStyle.mapPolygon,
      _ => FieldStyle.unknown,
    };
  }
}

/// A single selectable choice for a dropdown, radio or checkbox field.
///
/// Parsing is deliberately lenient: the backend may label the display text as
/// `name`, `label` or `value`, and the identifier as `id`, `optionId` or
/// `value`. When no id is present the option's name hash is used as a stable
/// fallback so selections can still be compared.
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

/// Describes how a field's options are fetched from the server at runtime.
///
/// Used when a field's choices are dynamic (e.g. a dependent dropdown) instead
/// of a static [ApiOption] list. Holds the [endpoint], HTTP [method] and any
/// query [params] the client should call to resolve the options.
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

/// Immutable definition of a single form field, exactly as described by the
/// backend.
///
/// This is the *blueprint* for a field — its identity ([fieldId], [key]),
/// label, data [fieldType], render [fieldStyle], whether it is [required], its
/// selectable [options], and any conditional-visibility rules ([dependsOn] +
/// [showWhen]). Container styles ([FieldStyle.popupForm] /
/// [FieldStyle.repeatablePopupForm]) nest their child fields in [subFields]
/// instead of options.
///
/// It carries no user input — that lives in [DynamicFieldModel], which wraps an
/// [ApiField]. Supports [fromJson] / [toJson] round-tripping and [copyWith].
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
    this.index,
    this.isDeleted,
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
  final int? index;
  final bool? isDeleted;

  /// Whether this field hosts a nested set of [subFields] rather than a value.
  bool get isPopupForm => fieldStyle == FieldStyle.popupForm;
  bool get isRepeatablePopupForm =>
      fieldStyle == FieldStyle.repeatablePopupForm;

  /// True for any style that contains child fields (pop-up or repeatable).
  bool get isFormContainer => isPopupForm || isRepeatablePopupForm;

  /// Returns [placeHolder] if non-null and non-empty, otherwise falls back to [label].
  String get effectiveplaceHolder =>
      (placeHolder != null && placeHolder!.isNotEmpty) ? placeHolder! : label;

  /// True when this field uses local visibility (dependsOn + showWhen, no dataSource).
  bool get hasVisibilityCondition =>
      dependsOn != null && showWhen != null && dataSource == null;

  List<String> get fieldData => options.map((option) => option.name).toList();

  /// Builds an [ApiField] from backend JSON.
  ///
  /// Container styles parse their nested `fields` recursively into [subFields];
  /// all other styles parse their flat `options` list. Keys are normalised to
  /// camelCase first so both snake_case and camelCase payloads are accepted.
  factory ApiField.fromJson(Map<String, dynamic> json) {
    final data = _normalizeJsonKeys(json);
    final resolvedFieldType = FieldType.fromApiValue(data['type']);
    final resolvedFieldStyle = FieldStyle.fromApiValue(data['style']);
    final rawOptions = data['options'] as List<dynamic>? ?? const [];

    List<ApiOption> options = const [];
    List<ApiField> subFields = const [];

    if (resolvedFieldStyle == FieldStyle.popupForm ||
        resolvedFieldStyle == FieldStyle.repeatablePopupForm) {
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
      index: data.containsKey('index') ? _asInt(data['index']) : null,
      isDeleted:
          data.containsKey('isDeleted') ? _asBool(data['isDeleted']) : null,
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
      FieldStyle.repeatablePopupForm => 'REPEATABLE_POPUP_FORM',
      FieldStyle.mapPolygon => 'MAP_POLYGON',
      FieldStyle.unknown => 'UNKNOWN',
    };

    final json = <String, dynamic>{
      'fieldId': fieldId,
      'label': label,
      'key': key,
      'type': typeValue,
      'style': styleValue,
      'required': required,
      if (placeHolder != null) 'placeHolder': placeHolder,
      if (isRepeatablePopupForm)
        'fields': subFields.map((field) => field.toJson()).toList()
      else
        'options': isPopupForm
            ? subFields.map((field) => field.toJson()).toList()
            : options.map((option) => option.toJson()).toList(),
      if (dependsOn != null) 'dependsOn': dependsOn,
      if (dataSource != null) 'dataSource': dataSource!.toJson(),
      if (showWhen != null) 'showWhen': showWhen,
      if (index != null) 'index': index,
      if (isDeleted != null) 'isDeleted': isDeleted,
    };
    return json;
  }

  ApiField copyWith({
    int? fieldId,
    String? label,
    String? key,
    FieldType? fieldType,
    FieldStyle? fieldStyle,
    bool? required,
    String? placeHolder,
    List<ApiOption>? options,
    List<ApiField>? subFields,
    String? dependsOn,
    FieldDataSource? dataSource,
    List<dynamic>? showWhen,
    int? index,
    bool? isDeleted,
  }) {
    return ApiField(
      fieldId: fieldId ?? this.fieldId,
      label: label ?? this.label,
      key: key ?? this.key,
      fieldType: fieldType ?? this.fieldType,
      fieldStyle: fieldStyle ?? this.fieldStyle,
      required: required ?? this.required,
      placeHolder: placeHolder ?? this.placeHolder,
      options: options ?? this.options,
      subFields: subFields ?? this.subFields,
      dependsOn: dependsOn ?? this.dependsOn,
      dataSource: dataSource ?? this.dataSource,
      showWhen: showWhen ?? this.showWhen,
      index: index ?? this.index,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}

/// Mutable runtime wrapper that binds a field's [ApiField] blueprint to the
/// user's live input.
///
/// This is the object screens actually render and mutate. It holds:
/// - [value]: the current user input (a scalar, a list, or a
///   `List<DynamicFieldModel>` for container fields);
/// - [resolvedOptions]: options after any [FieldDataSource] fetch, plus
///   [isLoadingOptions] / [optionsError] to reflect that fetch's status;
/// - [previewUrl]: display-only presigned URL(s) for camera/file fields;
/// - [hasError] / [errorMessage]: transient validation state set by the
///   validator and shown by the UI.
///
/// Display-only fields ([previewUrl], validation state) are intentionally
/// excluded from [toJson] and [copyWith] so they never leak into submissions.
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

  /// Monotonic counter used to discard stale async option fetches: a fetch
  /// captures the current generation and ignores its result if the value has
  /// since changed (guarding against out-of-order responses).
  int _fetchGeneration = 0;
  int get fetchGeneration => _fetchGeneration;
  void incrementFetchGeneration() => _fetchGeneration++;

  /// Creates a blank runtime model from a field blueprint, seeding a sensible
  /// initial [value] per style (nested models for containers, `false` for
  /// checkboxes, an empty list for file fields).
  factory DynamicFieldModel.fromApiField(ApiField field) {
    dynamic initialValue;
    if (field.isFormContainer) {
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

  /// Rehydrates a runtime model from a saved/submitted payload, restoring both
  /// the field definition and its previously entered [value] (recursing into
  /// nested container fields and normalising file references).
  factory DynamicFieldModel.fromJson(Map<String, dynamic> json) {
    final data = _normalizeJsonKeys(json);
    final apiField = ApiField.fromJson(data);
    dynamic resolvedValue;

    if (apiField.isFormContainer) {
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
    if (field.isFormContainer) {
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

/// A single file or image attachment, whether stored [isRemote] on the server
/// or held as a [localPath] on the device.
///
/// Normalises the various ways a file can be referenced (raw path, presigned
/// preview URL) into one object and derives a [displayName], file [extension]
/// and type flags ([isImage], [isPdf], [isDoc], [isTxt], [isPreviewable]) used
/// by the file viewer and upload widgets.
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

  /// Zips a field's stored paths with their preview URLs into one item per
  /// attachment, skipping entries where both are empty.
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

/// A farmer's submitted registration record: server-assigned [farmerId] and
/// [farmerCode] plus the list of answered [fields].
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

/// A single land parcel belonging to a farmer's registration.
///
/// Identified by its [submissionId] / [landId] and shown under [landTitle] /
/// [landCode]; [fields] holds the answered land-specific form fields.
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

/// A complete form definition: metadata ([formId], [formName], [prefixCode],
/// [formType], active state, whether geo-location is required) plus the ordered
/// list of [fields] that make up the form.
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

/// The land-form payload returned for a subcategory.
///
/// Wraps one or more candidate [forms] for the subcategory and preserves the
/// untouched [rawData] so it can be echoed back on submission. [firstUsableForm]
/// picks the form to render (preferring active forms that actually have fields).
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

  /// The best form to display: the first active form that has fields, or — if
  /// none are marked active — the first form with fields. Returns null when no
  /// form contains any fields.
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

// ─────────────────────────────────────────────────────────────────────────
// JSON helpers
//
// Shared, defensive utilities used throughout the models above to tolerate the
// backend's inconsistencies: mixed key casing, numbers sent as strings, single
// values where lists are expected, and so on. Keeping the parsing lenient here
// means the model constructors stay simple and never throw on odd payloads.
// ─────────────────────────────────────────────────────────────────────────

/// Returns a copy of [json] with every key converted to camelCase so the
/// models can read a single canonical key regardless of the source casing.
Map<String, dynamic> _normalizeJsonKeys(Map<String, dynamic> json) {
  final normalized = <String, dynamic>{};
  json.forEach((key, value) {
    normalized[_toCamelCase(key)] = value;
  });
  return normalized;
}

/// Converts a `snake_case` identifier to `camelCase`; returns [input] as-is
/// when it contains no underscores.
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

/// Safely coerces [value] (int, num or numeric string) to an int, returning
/// [fallback] when it cannot be parsed.
int _asInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

/// Safely coerces [value] to a bool, accepting native bools, numbers
/// (non-zero = true) and the strings `true`/`false`/`1`/`0`.
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

/// Recursively deep-copies a JSON map so callers can mutate the result without
/// affecting the original (used to preserve untouched raw payloads).
Map<String, dynamic> _deepCopyMap(Map<dynamic, dynamic> source) {
  return source.map(
    (key, value) => MapEntry(key.toString(), _deepCopyJsonValue(value)),
  );
}

/// Recursive helper for [_deepCopyMap] that copies nested maps and lists and
/// returns primitives unchanged.
Object? _deepCopyJsonValue(Object? value) {
  if (value is Map) return _deepCopyMap(value);
  if (value is List) return value.map(_deepCopyJsonValue).toList();
  return value;
}

/// Trims [value] to a string, collapsing null/empty results to null.
String? _asNullableString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

/// Normalises any raw file/option reference into a clean `List<String>`,
/// trimming entries and dropping blanks. A single non-list value becomes a
/// one-element list; null becomes an empty list.
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

/// Returns the first non-empty string from [raw] (via [cleanStringList]), or
/// null if there is none.
String? _firstCleanString(Object? raw) {
  final values = cleanStringList(raw);
  return values.isEmpty ? null : values.first;
}

/// Deep-copies a [DynamicFieldModel.value], which may be a nested list of
/// models, a plain list, a map, or a primitive — so [copyWith] does not share
/// mutable references with the original.
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

/// Returns the first non-null, non-blank (trimmed) string in [values], or null.
String? _firstNonEmptyString(List<String?> values) {
  for (final value in values) {
    final text = value?.trim();
    if (text != null && text.isNotEmpty) return text;
  }
  return null;
}

/// True when [value] parses as an absolute `http`/`https` URL.
bool _isHttpUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
}

/// Extracts a human-readable file name from a path or URL: strips query and
/// fragment, normalises separators, and URL-decodes the last path segment.
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

/// Extracts the lowercased file extension from a path or URL, or null when the
/// name has no usable extension.
String? _extensionFrom(String? raw) {
  final fileName = _fileNameFrom(raw);
  if (fileName == null) return null;
  final dotIndex = fileName.lastIndexOf('.');
  if (dotIndex < 0 || dotIndex == fileName.length - 1) return null;
  return fileName.substring(dotIndex + 1).toLowerCase();
}

/// Normalises a field's `showWhen` condition into a list of allowed values,
/// accepting either a list or a single scalar (parsed to int when possible).
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
