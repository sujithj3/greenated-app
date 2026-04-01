import '../core/network/network.dart';

/// Result of a successful image upload.
class ImageUploadResult {
  const ImageUploadResult({
    required this.imagePath,
    required this.previewUrl,
  });

  /// The S3 object path (e.g. "uploads/uuid.jpg") — stored as the field value
  /// and included in form submissions.
  final String imagePath;

  /// A presigned S3 URL for displaying the image — used for UI only, never
  /// submitted.
  final String previewUrl;
}

/// Service responsible for uploading images to the backend.
///
/// Endpoint: POST image/upload (multipart/form-data, key: "file")
/// Expected response: { statusCode: 200, hasError: false, data: { imagePath: "...", previewUrl: "..." } }
class ImageUploadService {
  const ImageUploadService({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// Uploads an image file and returns an [ImageUploadResult] on success.
  ///
  /// Throws [ApiException] on failure.
  Future<ImageUploadResult> uploadImage(String filePath) async {
    final response = await _apiClient.uploadFile<Map<String, dynamic>>(
      ApiEndpoints.imageUpload,
      filePath: filePath,
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
            : 'Image upload failed. Please try again.',
        statusCode: response.statusCode,
      );
    }

    final imagePath = response.data!['imagePath'] as String?;
    final previewUrl = response.data!['previewUrl'] as String?;

    if (imagePath == null || imagePath.isEmpty) {
      throw const ApiException('Upload succeeded but no image path was returned.');
    }
    if (previewUrl == null || previewUrl.isEmpty) {
      throw const ApiException('Upload succeeded but no preview URL was returned.');
    }

    return ImageUploadResult(imagePath: imagePath, previewUrl: previewUrl);
  }
}
