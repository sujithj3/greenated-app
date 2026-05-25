import 'package:flutter/foundation.dart';

import '../../models/api/api_models.dart';
import '../../services/image_upload_service.dart' show ImageUploadResult;

abstract class DynamicFieldFormViewModel extends ChangeNotifier {
  bool isFieldUploading(String key);

  Future<ImageUploadResult?> uploadImageOnly(
    String fieldKey,
    String localFilePath,
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
