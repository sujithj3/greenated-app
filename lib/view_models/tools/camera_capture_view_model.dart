import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/camera_capture_service.dart';
import '../../services/location_service.dart';
import '../../services/image_processing_service.dart';

class CameraCaptureViewModel extends ChangeNotifier {
  CameraCaptureViewModel({
    this.requiresLocation = false,
    CameraCaptureService? cameraService,
    LocationService? locationService,
    ImageProcessingService? imageService,
  })  : _cameraService = cameraService ?? CameraCaptureService(),
        _locationService = locationService ?? LocationService(),
        _imageService = imageService ?? ImageProcessingService() {
    locationText = requiresLocation ? 'Fetching location...' : '';
  }

  final bool requiresLocation;
  CameraController? cameraController;
  final CameraCaptureService _cameraService;
  final LocationService _locationService;
  final ImageProcessingService _imageService;

  bool isInitialized = false;
  String locationText = '';
  String latLngText = '';
  String timestampText = '';

  bool isFlashOn = false;

  String? capturedImagePath;
  bool isProcessing = false;
  bool isPreparingPreview = false;
  bool isFetchingLocation = false;
  bool shouldShowCameraSettings = false;
  bool shouldShowLocationServicesDisabledDialog = false;
  bool shouldShowLocationPermissionSettingsPrompt = false;
  String? processingError;

  DateTime? _locationFetchedAt;
  Future<void>? _locationFetchFuture;
  Future<void>? _initializeFuture;
  Future<void>? _cameraSettingsRefreshFuture;
  static const _locationStaleDuration = Duration(minutes: 2);
  static const _cameraPermissionDeniedMessage =
      'Camera permission denied. Enable camera access from Settings.';

  bool get _hasFreshLocation =>
      _locationFetchedAt != null &&
      DateTime.now().difference(_locationFetchedAt!) <= _locationStaleDuration;

  @override
  void dispose() {
    cameraController?.dispose();
    super.dispose();
  }

  Future<void> initialize() async {
    final runningInitialize = _initializeFuture;
    if (runningInitialize != null) {
      await runningInitialize;
      return;
    }
    final runningSettingsRefresh = _cameraSettingsRefreshFuture;
    if (runningSettingsRefresh != null) {
      await runningSettingsRefresh;
      return;
    }

    final future = _initializeWithPermissionRequest();
    _initializeFuture = future;

    try {
      await future;
    } finally {
      if (identical(_initializeFuture, future)) {
        _initializeFuture = null;
      }
    }
  }

  Future<void> refreshCameraPermissionAfterSettings() async {
    final runningInitialize = _initializeFuture;
    if (runningInitialize != null) {
      await runningInitialize;
      return;
    }
    final runningSettingsRefresh = _cameraSettingsRefreshFuture;
    if (runningSettingsRefresh != null) {
      await runningSettingsRefresh;
      return;
    }

    final future = _refreshCameraPermissionAfterSettings();
    _cameraSettingsRefreshFuture = future;

    try {
      await future;
    } finally {
      if (identical(_cameraSettingsRefreshFuture, future)) {
        _cameraSettingsRefreshFuture = null;
      }
    }
  }

  Future<void> _initializeWithPermissionRequest() async {
    _prepareForCameraStartup();

    final status = await _cameraService.requestCameraPermissionStatus();
    if (!status.isGranted) {
      _setCameraPermissionDenied();
      return;
    }

    await _initializeCamera();
  }

  Future<void> _refreshCameraPermissionAfterSettings() async {
    final status = await _cameraService.checkCameraPermissionStatus();
    if (!status.isGranted) {
      _setCameraPermissionDenied();
      return;
    }

    _prepareForCameraStartup();
    await _initializeCamera();
  }

  void _prepareForCameraStartup() {
    cameraController?.dispose();
    cameraController = null;
    isInitialized = false;
    processingError = null;
    shouldShowCameraSettings = false;
    isFlashOn = false;
    notifyListeners();
  }

  void _setCameraPermissionDenied() {
    final hadController = cameraController != null;
    final changed = isInitialized ||
        hadController ||
        isFlashOn ||
        processingError != _cameraPermissionDeniedMessage ||
        !shouldShowCameraSettings;

    cameraController?.dispose();
    cameraController = null;
    isInitialized = false;
    isFlashOn = false;
    processingError = _cameraPermissionDeniedMessage;
    shouldShowCameraSettings = true;

    if (changed) {
      notifyListeners();
    }
  }

  Future<void> _initializeCamera() async {
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

      if (requiresLocation) {
        // Start fetching location in background so it's ready before capture.
        unawaited(_fetchLocation());
      }
    } catch (e) {
      processingError = 'Failed to initialize camera: $e';
      notifyListeners();
    }
  }

  Future<bool> openCameraSettings() {
    return _cameraService.openCameraSettings();
  }

  Future<void> _fetchLocation() async {
    if (!requiresLocation) return;

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
      shouldShowLocationServicesDisabledDialog = false;
      shouldShowLocationPermissionSettingsPrompt = false;
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
    } on LocationException catch (e) {
      debugPrint('Location error: $e');
      locationText = 'Location unavailable';
      latLngText = '';
      _locationFetchedAt = null;
      if (e.isServiceDisabled) {
        shouldShowLocationServicesDisabledDialog = true;
      } else if (e.isPermissionDenied) {
        shouldShowLocationPermissionSettingsPrompt = true;
      }
    } catch (e) {
      debugPrint('Location error: $e');
      locationText = 'Location unavailable';
      latLngText = '';
      _locationFetchedAt = null;
    }
  }

  void acknowledgeLocationServicesDisabledDialog() {
    if (!shouldShowLocationServicesDisabledDialog) return;
    shouldShowLocationServicesDisabledDialog = false;
    notifyListeners();
  }

  void acknowledgeLocationPermissionSettingsPrompt() {
    if (!shouldShowLocationPermissionSettingsPrompt) return;
    shouldShowLocationPermissionSettingsPrompt = false;
    notifyListeners();
  }

  Future<void> openLocationSettings() async {
    await _locationService.openAppSettings();
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
        cameraController!.value.isTakingPicture ||
        isPreparingPreview) {
      return;
    }

    try {
      isPreparingPreview = true;
      notifyListeners();

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
      isPreparingPreview = false;
      notifyListeners();

      if (requiresLocation && !_hasFreshLocation) {
        unawaited(_fetchLocation());
      }
    } catch (e) {
      isPreparingPreview = false;
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
