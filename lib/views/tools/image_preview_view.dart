// Image preview view — confirms a photo captured in CameraCaptureView.
//
// Shows the captured image and lets the user save it (returning the saved
// file path to the caller) or retake it. Delegates image processing and
// persistence to the shared CameraCaptureViewModel.

import 'dart:io';
import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../utils/camera_photo_frame.dart';
import '../../utils/snack_bar_helper.dart';
import '../../view_models/tools/camera_capture_view_model.dart';
import '../../widgets/camera_preview_loader.dart';

class ImagePreviewView extends StatelessWidget {
  final CameraCaptureViewModel viewModel;

  const ImagePreviewView({super.key, required this.viewModel});

  Future<void> _save(BuildContext context) async {
    if (viewModel.isProcessing) return;

    final resultPath = await viewModel.processAndSave();
    if (resultPath != null) {
      if (context.mounted) {
        context.showSnack('Image saved successfully', success: true);
        Navigator.pop(context, resultPath);
      }
    } else {
      if (context.mounted) {
        context.showSnack(viewModel.processingError ?? 'Failed to save image');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Preview'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: viewModel
              .retake, // Instead of popping the route, retake unsets the image
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildImageWithOverlay(),

          // Loading overlay during processing
          if (viewModel.isProcessing)
            Container(
              color: Colors.black.withValues(alpha: 0.7),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: 16),
                    Text(
                      'Saving Image...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        color: Colors.black,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            OutlinedButton.icon(
              onPressed: viewModel.isProcessing ? null : viewModel.retake,
              icon: const Icon(Icons.refresh, color: Colors.white),
              label:
                  const Text('Retake', style: TextStyle(color: Colors.white)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            ElevatedButton.icon(
              onPressed:
                  (viewModel.isProcessing || viewModel.isFetchingLocation)
                      ? null
                      : () => _save(context),
              icon: const Icon(Icons.check),
              label: Text(viewModel.isFetchingLocation
                  ? 'Fetching Location...'
                  : 'Save'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageWithOverlay() {
    return Builder(
      builder: (context) {
        return Center(
          child: AspectRatio(
            aspectRatio: CameraPhotoFrame.aspectRatioForOrientation(
              MediaQuery.orientationOf(context),
            ),
            child: ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final devicePixelRatio =
                          MediaQuery.devicePixelRatioOf(context);
                      final cacheWidth = _previewCacheDimension(
                        constraints.maxWidth,
                        devicePixelRatio,
                      );
                      final cacheHeight = _previewCacheDimension(
                        constraints.maxHeight,
                        devicePixelRatio,
                      );

                      return Image.file(
                        File(viewModel.capturedImagePath!),
                        fit: BoxFit.cover,
                        cacheWidth: cacheWidth,
                        cacheHeight: cacheHeight,
                        filterQuality: FilterQuality.medium,
                        frameBuilder:
                            (context, child, frame, wasSynchronouslyLoaded) {
                          if (wasSynchronouslyLoaded || frame != null) {
                            return child;
                          }

                          return const CameraPreviewLoader();
                        },
                      );
                    },
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    right: 20,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: _buildOverlayLabel(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  int? _previewCacheDimension(double logicalSize, double devicePixelRatio) {
    if (!logicalSize.isFinite || logicalSize <= 0) return null;
    return (logicalSize * devicePixelRatio).round();
  }

  Widget _buildOverlayLabel() {
    final overlayTexts = [
      if (viewModel.locationText.trim().isNotEmpty) viewModel.locationText,
      if (viewModel.latLngText.trim().isNotEmpty) viewModel.latLngText,
      if (viewModel.timestampText.trim().isNotEmpty) viewModel.timestampText,
    ];

    if (overlayTexts.isEmpty) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (index, text) in overlayTexts.indexed) ...[
            if (index > 0) const SizedBox(height: 4),
            _buildOverlayText(text),
          ],
        ],
      ),
    );
  }

  Widget _buildOverlayText(String text) {
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
