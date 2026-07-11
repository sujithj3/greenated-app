import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

/// Thin wrapper around the device camera and its runtime permission.
///
/// Centralises the camera-permission handshake (via `permission_handler`) and
/// camera discovery (via the `camera` plugin) so the capture UI does not deal
/// with those plugins directly. Callers use it to ensure permission is granted,
/// open app settings when it is permanently denied, and obtain a
/// [CameraDescription] (typically the rear camera) to open a preview.
class CameraCaptureService {
  /// Requests camera permission and returns whether it ended up granted.
  Future<bool> requestCameraPermission() async {
    final status = await requestCameraPermissionStatus();
    return status.isGranted;
  }

  /// Requests camera permission and returns the resulting [PermissionStatus],
  /// exposing the full status (e.g. denied vs. permanently denied) rather than
  /// just a boolean.
  Future<PermissionStatus> requestCameraPermissionStatus() {
    return Permission.camera.request();
  }

  /// Returns the current camera [PermissionStatus] without prompting the user.
  Future<PermissionStatus> checkCameraPermissionStatus() {
    return Permission.camera.status;
  }

  /// Opens the system app-settings page so the user can grant a permission that
  /// was permanently denied.
  Future<bool> openCameraSettings() {
    return openAppSettings();
  }

  /// Gets the list of available cameras
  Future<List<CameraDescription>> getAvailableCameras() async {
    try {
      return await availableCameras();
    } catch (e) {
      return [];
    }
  }

  /// Returns the first back camera, or the first available camera if no back camera is found
  Future<CameraDescription?> getBackCamera() async {
    final cameras = await getAvailableCameras();
    if (cameras.isEmpty) return null;

    for (final camera in cameras) {
      if (camera.lensDirection == CameraLensDirection.back) {
        return camera;
      }
    }
    return cameras.first;
  }
}
