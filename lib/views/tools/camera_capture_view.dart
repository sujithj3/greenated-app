import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../utils/camera_photo_frame.dart';
import '../../view_models/tools/camera_capture_view_model.dart';
import 'image_preview_view.dart';

class CameraCaptureView extends StatefulWidget {
  const CameraCaptureView({super.key});

  @override
  State<CameraCaptureView> createState() => _CameraCaptureViewState();
}

class _CameraCaptureViewState extends State<CameraCaptureView>
    with WidgetsBindingObserver {
  late final CameraCaptureViewModel _vm;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _vm = CameraCaptureViewModel()..initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _vm.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _vm.shouldShowCameraSettings &&
        !_vm.isInitialized) {
      _vm.initialize();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        if (_vm.capturedImagePath != null) {
          return ImagePreviewView(viewModel: _vm);
        }

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('Capture Photo'),
            actions: [
              if (_vm.isInitialized)
                IconButton(
                  icon: Icon(_vm.isFlashOn ? Icons.flash_on : Icons.flash_off),
                  onPressed: _vm.toggleFlash,
                ),
            ],
          ),
          body: _buildBody(),
        );
      },
    );
  }

  Widget _buildBody() {
    if (_vm.processingError != null && !_vm.isInitialized) {
      if (_vm.shouldShowCameraSettings) {
        return _buildCameraPermissionDenied();
      }

      return Center(
        child: Text(
          _vm.processingError!,
          style: const TextStyle(color: Colors.red, fontSize: 16),
        ),
      );
    }

    if (!_vm.isInitialized || _vm.cameraController == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    return SafeArea(
      top: false,
      child: Column(
        children: [
          const SizedBox(height: 24),
          AspectRatio(
            aspectRatio: CameraPhotoFrame.aspectRatioForOrientation(
              MediaQuery.orientationOf(context),
            ),
            child: _buildCameraPreview(),
          ),
          const SizedBox(height: 100),
          _buildCaptureButton(),
          const Spacer(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCameraPermissionDenied() {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                color: Colors.white70,
                size: 56,
              ),
              const SizedBox(height: 18),
              Text(
                _vm.processingError!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _vm.openCameraSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Open Settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCaptureButton() {
    return FloatingActionButton(
      onPressed: _vm.captureImage,
      backgroundColor: AppColors.primary,
      child: const Icon(
        Icons.camera_alt,
        color: Colors.white,
        size: 30,
      ),
    );
  }

  Widget _buildCameraPreview() {
    final controller = _vm.cameraController!;
    final previewSize = controller.value.previewSize;

    if (previewSize == null) {
      return CameraPreview(controller);
    }

    final isPortrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;
    final previewWidth = isPortrait ? previewSize.height : previewSize.width;
    final previewHeight = isPortrait ? previewSize.width : previewSize.height;

    return ClipRect(
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: previewWidth,
            height: previewHeight,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }
}
