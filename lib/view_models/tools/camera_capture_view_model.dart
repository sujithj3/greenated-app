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
  bool isFetchingLocation = false;
  bool shouldShowCameraSettings = false;
  String? processingError;

  DateTime? _locationFetchedAt;
  Future<void>? _locationFetchFuture;
  static const _locationStaleDuration = Duration(minutes: 2);

  bool get _hasFreshLocation =>
      _locationFetchedAt != null &&
      DateTime.now().difference(_locationFetchedAt!) <= _locationStaleDuration;

  @override
  void dispose() {
    cameraController?.dispose();
    super.dispose();
  }

  Future<void> initialize() async {
    isInitialized = false;
    processingError = null;
    shouldShowCameraSettings = false;
    notifyListeners();

    final hasPermission = await _cameraService.requestCameraPermission();
    if (!hasPermission) {
      processingError =
          'Camera permission denied. Enable camera access from Settings.';
      shouldShowCameraSettings = true;
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
      ResolutionPreset.max,
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

  Future<void> openCameraSettings() async {
    await _cameraService.openCameraSettings();
  }

  Future<void> _fetchLocation() async {
    if (_locationFetchFuture != null) {
      return _locationFetchFuture;
    }

    isFetchingLocation = true;
    notifyListeners();

    _locationFetchFuture = _fetchLocationInternal().whenComplete(() {
      isFetchingLocation = false;
      _locationFetchFuture = null;

      // Set timestamp if picture hasn't been captured yet
      if (capturedImagePath == null) {
        timestampText =
            DateFormat("dd MMM yyyy, hh:mm a 'IST'").format(DateTime.now());
      }
      notifyListeners();
    });

    return _locationFetchFuture;
  }

  Future<void> _fetchLocationInternal() async {
    try {
      final position = await _locationService.getCurrentPosition();
      final latitude = position.latitude.toStringAsFixed(6);
      final longitude = position.longitude.toStringAsFixed(6);

      latLngText = 'Lat: $latitude, Lng: $longitude';
      locationText = 'GPS location captured';
      _locationFetchedAt = DateTime.now();
      notifyListeners();

      try {
        final addressResult = await _locationService.reverseGeocode(
          position.latitude,
          position.longitude,
        );

        final parts = <String>[];
        if (addressResult.village.isNotEmpty) parts.add(addressResult.village);
        if (addressResult.district.isNotEmpty) {
          if (!parts.contains(addressResult.district)) {
            parts.add(addressResult.district);
          }
        }
        if (addressResult.state.isNotEmpty) parts.add(addressResult.state);

        if (parts.isNotEmpty) {
          locationText = parts.join(', ');
        } else if (addressResult.address.isNotEmpty) {
          locationText = addressResult.address;
        }
      } catch (e) {
        debugPrint('Reverse geocode error: $e');
      }
    } catch (e) {
      debugPrint('Location error: $e');
      locationText = 'Location unavailable';
      latLngText = '';
      _locationFetchedAt = null;
    }
  }

  Future<void> toggleFlash() async {
    if (cameraController == null || !cameraController!.value.isInitialized) {
      return;
    }
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
    if (cameraController == null ||
        !cameraController!.value.isInitialized ||
        cameraController!.value.isTakingPicture) {
      return;
    }

    try {
      final file = await cameraController!.takePicture();

      // Automatically turn off flash/torch after capture
      if (isFlashOn) {
        await cameraController!.setFlashMode(FlashMode.off);
        isFlashOn = false;
      }

      // Update timestamp to the actual moment of capture
      timestampText =
          DateFormat("dd MMM yyyy, hh:mm a 'IST'").format(DateTime.now());

      // Reuse cached location if it's fresh (within 2 minutes).
      // Trigger background re-fetch if location was never obtained or has gone stale.
      capturedImagePath = file.path;
      notifyListeners();

      final hadLocationFetchInProgress = _locationFetchFuture != null;
      if (!_hasFreshLocation) {
        await _fetchLocation();
        if (hadLocationFetchInProgress && !_hasFreshLocation) {
          await _fetchLocation();
        }
      }
    } catch (e) {
      isFetchingLocation = false;
      _locationFetchFuture = null;
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
    if (capturedImagePath == null || isProcessing) return null;

    isProcessing = true;
    processingError = null;
    notifyListeners();

    try {
      // Ensure we have a timestamp
      if (timestampText.isEmpty) {
        timestampText =
            DateFormat("dd MMM yyyy, hh:mm a 'IST'").format(DateTime.now());
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
        processingError =
            'Image verified, but could not explicitly save to Gallery. Proceeding.';
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
