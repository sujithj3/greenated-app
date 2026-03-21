import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../view_models/tools/camera_capture_view_model.dart';
import 'image_preview_view.dart';

class CameraCaptureView extends StatefulWidget {
  const CameraCaptureView({super.key});

  @override
  State<CameraCaptureView> createState() => _CameraCaptureViewState();
}

class _CameraCaptureViewState extends State<CameraCaptureView> {
  late final CameraCaptureViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = CameraCaptureViewModel()..initialize();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
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
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
          floatingActionButton: _vm.isInitialized && !_vm.isFetchingLocation
              ? FloatingActionButton(
                  onPressed: _vm.captureImage,
                  backgroundColor: AppColors.primary,
                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 30),
                )
              : null,
        );
      },
    );
  }

  Widget _buildBody() {
    if (_vm.processingError != null && !_vm.isInitialized) {
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

    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera Preview
        CameraPreview(_vm.cameraController!),
        if (_vm.isFetchingLocation)
          Container(
            color: Colors.black.withValues(alpha: 0.5),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text(
                    'Fetching precise location...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
