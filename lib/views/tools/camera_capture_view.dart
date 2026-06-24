import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../utils/camera_photo_frame.dart';
import '../../utils/location_services_dialog.dart';
import '../../view_models/tools/camera_capture_view_model.dart';
import '../../widgets/camera_preview_loader.dart';
import 'image_preview_view.dart';

class CameraCaptureView extends StatefulWidget {
  final bool requiresLocation;

  const CameraCaptureView({
    super.key,
    this.requiresLocation = false,
  });

  @override
  State<CameraCaptureView> createState() => _CameraCaptureViewState();
}

class _CameraCaptureViewState extends State<CameraCaptureView>
    with WidgetsBindingObserver {
  late final CameraCaptureViewModel _vm;
  bool _isShowingLocationServicesDialog = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _vm = CameraCaptureViewModel(
      requiresLocation: widget.requiresLocation,
    )..initialize();
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
        _showLocationServicesDisabledDialogIfNeeded();

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
                  onPressed: _vm.isPreparingPreview ? null : _vm.toggleFlash,
                ),
            ],
          ),
          body: Stack(
            fit: StackFit.expand,
            children: [
              _buildBody(),
              if (_vm.isPreparingPreview)
                CameraPreviewLoader(
                  backgroundColor: Colors.black.withValues(alpha: 0.78),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showLocationServicesDisabledDialogIfNeeded() {
    if (!_vm.shouldShowLocationServicesDisabledDialog ||
        _isShowingLocationServicesDialog) {
      return;
    }

    _isShowingLocationServicesDialog = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _isShowingLocationServicesDialog = false;
        return;
      }

      _vm.acknowledgeLocationServicesDisabledDialog();
      await showLocationServicesDisabledDialog(context);
      _isShowingLocationServicesDialog = false;
    });
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final frameAspectRatio = CameraPhotoFrame.aspectRatioForOrientation(
            MediaQuery.orientationOf(context),
          );
          final topGap = (constraints.maxHeight * 0.04).clamp(12.0, 24.0);
          final actionGap = (constraints.maxHeight * 0.08).clamp(24.0, 64.0);
          const captureButtonSize = 56.0;
          const bottomGap = 24.0;
          final availablePreviewHeight = (constraints.maxHeight -
                  topGap -
                  actionGap -
                  captureButtonSize -
                  bottomGap)
              .clamp(0.0, double.infinity);
          final widthBasedPreviewHeight =
              constraints.maxWidth / frameAspectRatio;
          final previewHeight = widthBasedPreviewHeight > availablePreviewHeight
              ? availablePreviewHeight
              : widthBasedPreviewHeight;
          final previewWidth = previewHeight * frameAspectRatio;

          return Column(
            children: [
              SizedBox(height: topGap),
              SizedBox(
                width: previewWidth,
                height: previewHeight,
                child: _buildCameraPreview(),
              ),
              SizedBox(height: actionGap),
              _buildCaptureButton(),
              const Spacer(),
              const SizedBox(height: bottomGap),
            ],
          );
        },
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
      onPressed: _vm.isPreparingPreview ? null : _vm.captureImage,
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
