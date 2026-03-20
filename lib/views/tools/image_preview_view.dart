import 'dart:io';
import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../utils/snack_bar_helper.dart';
import '../../view_models/tools/camera_capture_view_model.dart';

class ImagePreviewView extends StatelessWidget {
  final CameraCaptureViewModel viewModel;

  const ImagePreviewView({super.key, required this.viewModel});

  Future<void> _save(BuildContext context) async {
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
          onPressed: viewModel.retake, // Instead of popping the route, retake unsets the image
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            File(viewModel.capturedImagePath!),
            fit: BoxFit.contain,
          ),
          
          // UI representation of the overlay (before it is permanently burnt in)
          Positioned(
            top: 20,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    viewModel.locationText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (viewModel.latLngText.isNotEmpty) ...[
                    Text(
                      viewModel.latLngText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    viewModel.timestampText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

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
              label: const Text('Retake', style: TextStyle(color: Colors.white)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            ElevatedButton.icon(
              onPressed: viewModel.isProcessing ? null : () => _save(context),
              icon: const Icon(Icons.check),
              label: const Text('Save'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
