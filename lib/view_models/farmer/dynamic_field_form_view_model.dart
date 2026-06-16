import 'package:flutter/foundation.dart';

import '../../models/api/api_models.dart';
import '../../services/file_upload_service.dart' show FileUploadResult;
import '../../services/image_upload_service.dart' show ImageUploadResult;

abstract class DynamicFieldFormViewModel extends ChangeNotifier {
  String? get lastUploadErrorMessage;

  bool isFieldUploading(String key);

  Future<ImageUploadResult?> uploadImageOnly(
    String fieldKey,
    String localFilePath,
  );

  Future<FileUploadResult?> uploadFilesOnly(
    String fieldKey,
    List<String> localFilePaths,
  );

  Future<void> handleSubfieldDependencyChange(
    String changedKey,
    List<DynamicFieldModel> fieldList,
  );

  Future<void> retrySubfieldOptions(
    String fieldKey,
    List<DynamicFieldModel> fieldList,
  );
}
