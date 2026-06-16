import '../core/network/network.dart';
import '../models/api/api_models.dart';
import 'upload_compression_service.dart';

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
  FileUploadService({
    required ApiClient apiClient,
    UploadCompressionService? uploadCompressionService,
  })  : _apiClient = apiClient,
        _uploadCompressionService =
            uploadCompressionService ?? const UploadCompressionService();

  final ApiClient _apiClient;
  final UploadCompressionService _uploadCompressionService;

  Future<FileUploadResult> uploadFiles({
    required String fieldKey,
    required List<String> filePaths,
  }) async {
    final cleanedPaths = cleanStringList(filePaths);
    if (cleanedPaths.isEmpty) {
      throw const ApiException('No files selected.');
    }

    UploadValidationResult? preparedUpload;
    try {
      preparedUpload = await _uploadCompressionService.prepareFiles(
        cleanedPaths,
      );

      final response = await _apiClient.uploadFiles<Map<String, dynamic>>(
        ApiEndpoints.filesUpload,
        filePaths: preparedUpload.filePaths,
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
    } finally {
      if (preparedUpload != null) {
        await _uploadCompressionService.cleanupTemporaryFiles(preparedUpload);
      }
    }
  }
}
