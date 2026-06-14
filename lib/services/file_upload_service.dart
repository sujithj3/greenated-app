import '../core/network/network.dart';
import '../models/api/api_models.dart';

class FileUploadResult {
  const FileUploadResult({
    required this.paths,
    required this.previewUrls,
  });

  final List<String> paths;
  final List<String> previewUrls;

  bool get hasIncompleteData =>
      paths.isEmpty || paths.length != previewUrls.length;

  factory FileUploadResult.fromJson(Map<String, dynamic> json) {
    return FileUploadResult(
      paths: cleanStringList(json['path']),
      previewUrls: cleanStringList(json['previewUrl']),
    );
  }
}

class FileUploadService {
  const FileUploadService({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<FileUploadResult> uploadFiles({
    required String fieldKey,
    required List<String> filePaths,
  }) async {
    final cleanedPaths = cleanStringList(filePaths);
    if (cleanedPaths.isEmpty) {
      throw const ApiException('No files selected.');
    }

    final response = await _apiClient.uploadFiles<Map<String, dynamic>>(
      ApiEndpoints.filesUpload,
      filePaths: cleanedPaths,
      fileKey: 'file',
      decoder: (raw) {
        if (raw is Map) return Map<String, dynamic>.from(raw);
        return null;
      },
    );

    if (response.hasError || response.data == null) {
      throw ApiException(
        response.message.isNotEmpty
            ? response.message
            : 'File upload failed. Please try again.',
        statusCode: response.statusCode,
      );
    }

    final result = FileUploadResult.fromJson(response.data!);
    if (result.paths.isEmpty) {
      throw const ApiException(
        'Upload succeeded but no file path was returned.',
      );
    }
    return result;
  }
}
