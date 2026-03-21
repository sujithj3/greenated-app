import '../core/network/network.dart';

/// Service responsible for uploading images to the backend.
///
/// Endpoint: POST image/upload (multipart/form-data, key: "file")
/// Expected response: { statusCode: 200, hasError: false, data: { url: "..." } }
class ImageUploadService {
  const ImageUploadService({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// Uploads an image file and returns the remote URL on success.
  ///
  /// Throws [ApiException] on failure.
  Future<String> uploadImage(String filePath) async {
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

    final url = response.data!['url'] as String?;
    if (url == null || url.isEmpty) {
      throw const ApiException('Upload succeeded but no image URL was returned.');
    }

    return url;
  }
}
