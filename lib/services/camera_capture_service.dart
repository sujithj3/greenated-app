import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraCaptureService {
  /// Checks and requests camera permissions
  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
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
