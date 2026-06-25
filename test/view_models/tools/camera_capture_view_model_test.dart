import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenated/services/camera_capture_service.dart';
import 'package:greenated/view_models/tools/camera_capture_view_model.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  group('CameraCaptureViewModel camera permission flow', () {
    test('guards overlapping initialize calls', () async {
      final requestCompleter = Completer<PermissionStatus>();
      final service = FakeCameraCaptureService(
        requestCompleter: requestCompleter,
      );
      final vm = CameraCaptureViewModel(cameraService: service);
      addTearDown(vm.dispose);

      final firstInitialize = vm.initialize();
      final secondInitialize = vm.initialize();
      await Future<void>.delayed(Duration.zero);

      expect(service.requestCount, 1);

      requestCompleter.complete(PermissionStatus.denied);
      await Future.wait([firstInitialize, secondInitialize]);

      expect(service.requestCount, 1);
      expect(vm.shouldShowCameraSettings, isTrue);
      expect(vm.processingError, contains('Camera permission denied'));
    });

    test('keeps denied screen stable when settings return is still denied',
        () async {
      for (final status in [
        PermissionStatus.denied,
        PermissionStatus.permanentlyDenied,
        PermissionStatus.restricted,
      ]) {
        final service = FakeCameraCaptureService(
          requestStatus: PermissionStatus.denied,
          checkStatus: status,
        );
        final vm = CameraCaptureViewModel(cameraService: service);

        await vm.initialize();

        expect(vm.shouldShowCameraSettings, isTrue);
        expect(vm.processingError, contains('Camera permission denied'));

        final snapshots = <List<Object?>>[];
        vm.addListener(
          () => snapshots.add([
            vm.isInitialized,
            vm.shouldShowCameraSettings,
            vm.processingError,
          ]),
        );

        await vm.refreshCameraPermissionAfterSettings();

        expect(
          snapshots,
          isEmpty,
          reason: 'still-denied status $status should not emit loader state',
        );
        expect(service.requestCount, 1);
        expect(service.checkCount, 1);
        expect(service.getBackCameraCount, 0);
        expect(vm.isInitialized, isFalse);
        expect(vm.shouldShowCameraSettings, isTrue);
        expect(vm.processingError, contains('Camera permission denied'));

        vm.dispose();
      }
    });

    test('granted settings return clears denied state without requesting again',
        () async {
      final service = FakeCameraCaptureService(
        requestStatus: PermissionStatus.denied,
        checkStatus: PermissionStatus.granted,
      );
      final vm = CameraCaptureViewModel(cameraService: service);
      addTearDown(vm.dispose);

      await vm.initialize();
      await vm.refreshCameraPermissionAfterSettings();

      expect(service.requestCount, 1);
      expect(service.checkCount, 1);
      expect(service.getBackCameraCount, 1);
      expect(vm.shouldShowCameraSettings, isFalse);
      expect(vm.processingError, 'No camera found.');
    });
  });
}

class FakeCameraCaptureService extends CameraCaptureService {
  FakeCameraCaptureService({
    this.requestStatus = PermissionStatus.denied,
    this.checkStatus = PermissionStatus.denied,
    this.requestCompleter,
    this.backCamera,
  });

  PermissionStatus requestStatus;
  PermissionStatus checkStatus;
  Completer<PermissionStatus>? requestCompleter;
  CameraDescription? backCamera;
  int requestCount = 0;
  int checkCount = 0;
  int getBackCameraCount = 0;
  int openSettingsCount = 0;

  @override
  Future<PermissionStatus> requestCameraPermissionStatus() {
    requestCount++;
    final completer = requestCompleter;
    if (completer != null) {
      return completer.future;
    }
    return Future.value(requestStatus);
  }

  @override
  Future<PermissionStatus> checkCameraPermissionStatus() {
    checkCount++;
    return Future.value(checkStatus);
  }

  @override
  Future<CameraDescription?> getBackCamera() {
    getBackCameraCount++;
    return Future.value(backCamera);
  }

  @override
  Future<bool> openCameraSettings() {
    openSettingsCount++;
    return Future.value(true);
  }
}
