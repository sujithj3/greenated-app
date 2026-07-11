import '../core/network/network.dart';
import '../models/api/api_models.dart';
import 'upload_compression_service.dart';

/// Result of a successful multi-file upload.
///
/// Pairs the server-assigned storage [paths] (stored as field values and sent
/// in form submissions) with their presigned [previewUrls] (display-only).
/// [hasIncompleteData] flags a mismatch or missing paths so callers can guard
/// against partial uploads.
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

/// Service responsible for uploading and deleting document/file attachments.
///
/// Compresses and validates the selected files through
/// [UploadCompressionService], POSTs them as multipart/form-data to
/// [ApiEndpoints.filesUpload], and returns a [FileUploadResult] of storage
/// paths plus presigned preview URLs. Also deletes a previously uploaded file
/// by its storage path. Backs the file-picker form fields and their view
/// models; images are handled separately by `ImageUploadService`.
class FileUploadService {
  FileUploadService({
    required ApiClient apiClient,
    UploadCompressionService? uploadCompressionService,
  })  : _apiClient = apiClient,
        _uploadCompressionService =
            uploadCompressionService ?? const UploadCompressionService();

  final ApiClient _apiClient;
  final UploadCompressionService _uploadCompressionService;

  /// Compresses and uploads the files at [filePaths], returning a
  /// [FileUploadResult] with their storage paths and preview URLs.
  ///
  /// Temporary compressed files are always cleaned up afterwards. Throws
  /// [ApiException] when no files are selected, the upload fails, or the server
  /// returns no path.
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

  /// Deletes the uploaded file at [path] from the backend.
  ///
  /// [fieldId] and [submissionId], when provided, scope the delete to a
  /// specific field/submission. Throws [ApiException] on an empty path or a
  /// failed request.
  Future<void> deleteFileByPath(
    String path, {
    int? fieldId,
    int? submissionId,
  }) async {
    final trimmedPath = path.trim();
    if (trimmedPath.isEmpty) {
      throw const ApiException('File path not found.');
    }

    final body = <String, dynamic>{
      'path': trimmedPath,
      if (fieldId != null) 'fieldId': fieldId,
      if (submissionId != null) 'submissionId': submissionId,
    };

    final response = await _apiClient.send<Map<String, dynamic>>(
      ApiRequest(
        method: ApiMethod.delete,
        path: ApiEndpoints.deleteFile,
        body: body,
      ),
      decoder: (raw) {
        if (raw is Map) return Map<String, dynamic>.from(raw);
        return null;
      },
    );

    if (response.hasError) {
      throw ApiException(
        response.message.isNotEmpty
            ? response.message
            : 'File delete failed. Please try again.',
        statusCode: response.statusCode,
      );
    }
  }
}
