import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:gal/gal.dart';
import '../../services/camera_capture_service.dart';
import '../../services/location_service.dart';
import '../../services/image_processing_service.dart';

class CameraCaptureViewModel extends ChangeNotifier {
  CameraController? cameraController;
  final CameraCaptureService _cameraService = CameraCaptureService();
  final LocationService _locationService = LocationService();
  final ImageProcessingService _imageService = ImageProcessingService();

  bool isInitialized = false;
  String locationText = 'Fetching location...';
  String latLngText = '';
  String timestampText = '';
  
  bool isFlashOn = false;
  
  String? capturedImagePath;
  bool isProcessing = false;
  String? processingError;

  @override
  void dispose() {
    cameraController?.dispose();
    super.dispose();
  }

  Future<void> initialize() async {
    isInitialized = false;
    notifyListeners();

    final hasPermission = await _cameraService.requestCameraPermission();
    if (!hasPermission) {
      processingError = 'Camera permission denied.';
      notifyListeners();
      return;
    }

    final camera = await _cameraService.getBackCamera();
    if (camera == null) {
      processingError = 'No camera found.';
      notifyListeners();
      return;
    }

    cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await cameraController!.initialize();
      isInitialized = true;
      notifyListeners();

      // Start fetching location in background so it's ready before capture
      _fetchLocation();
    } catch (e) {
      processingError = 'Failed to initialize camera: $e';
      notifyListeners();
    }
  }

  Future<void> _fetchLocation() async {
    try {
      final position = await _locationService.getCurrentPosition();
      final addressResult = await _locationService.reverseGeocode(
        position.latitude,
        position.longitude,
      );

      final parts = <String>[];
      if (addressResult.village.isNotEmpty) parts.add(addressResult.village);
      if (addressResult.district.isNotEmpty) {
        if (!parts.contains(addressResult.district)) parts.add(addressResult.district);
      }
      if (addressResult.state.isNotEmpty) parts.add(addressResult.state);

      latLngText = 'Lat: ${position.latitude.toStringAsFixed(6)}, Lng: ${position.longitude.toStringAsFixed(6)}';

      if (parts.isNotEmpty) {
        locationText = parts.join(', ');
      } else {
        locationText = 'Unknown location';
      }
    } catch (e) {
      debugPrint('Location error: $e');
      locationText = 'Location unavailable';
    }

    timestampText = DateFormat("dd MMM yyyy, hh:mm a 'IST'").format(DateTime.now());
    notifyListeners();
  }

  Future<void> toggleFlash() async {
    if (cameraController == null || !cameraController!.value.isInitialized) return;
    try {
      isFlashOn = !isFlashOn;
      await cameraController!.setFlashMode(
        isFlashOn ? FlashMode.torch : FlashMode.off,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to toggle flash: $e');
    }
  }

  Future<void> captureImage() async {
    if (cameraController == null || !cameraController!.value.isInitialized || cameraController!.value.isTakingPicture) {
      return;
    }

    try {
      final file = await cameraController!.takePicture();
      
      // Automatically turn off flash/torch after capture
      if (isFlashOn) {
        await cameraController!.setFlashMode(FlashMode.off);
        isFlashOn = false;
      }

      // Refresh location and time specifically for the capture point
      // before showing the preview screen
      await _fetchLocation();

      capturedImagePath = file.path;
      notifyListeners();
    } catch (e) {
      debugPrint('Capture error: $e');
      processingError = 'Failed to capture image.';
      notifyListeners();
    }
  }

  void retake() {
    capturedImagePath = null;
    processingError = null;
    notifyListeners();
  }

  Future<String?> processAndSave() async {
    if (capturedImagePath == null) return null;

    isProcessing = true;
    processingError = null;
    notifyListeners();

    try {
      // Ensure we have a timestamp
      if (timestampText.isEmpty) {
        timestampText = DateFormat("dd MMM yyyy, hh:mm a 'IST'").format(DateTime.now());
      }
      
      final savedPath = await _imageService.processImage(
        originalImagePath: capturedImagePath!,
        locationText: locationText,
        latLngText: latLngText,
        timestampText: timestampText,
      );

      try {
        final hasAccess = await Gal.hasAccess();
        if (!hasAccess) {
          await Gal.requestAccess();
        }
        await Gal.putImage(savedPath);
      } catch (e) {
        debugPrint('Failed to save to gallery: $e');
        processingError = 'Image verified, but could not explicitly save to Gallery. Proceeding.';
      }

      return savedPath;
    } catch (e) {
      debugPrint('Processing error: $e');
      processingError = 'Failed to process image: $e';
      isProcessing = false;
      notifyListeners();
      return null;
    }
  }
}
