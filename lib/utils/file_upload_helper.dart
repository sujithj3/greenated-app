import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'snack_bar_helper.dart';

const List<String> allowedUploadExtensions = <String>[
  'jpg',
  'jpeg',
  'png',
  'gif',
  'webp',
  'bmp',
  'heic',
  'heif',
  'pdf',
  'doc',
  'docx',
  'txt',
];
const int maxUploadSelectionCount = 5;

enum FileUploadSource {
  camera,
  files,
}

Future<List<String>> pickDynamicUploadFiles(
  BuildContext context, {
  bool requiresLocationForCamera = false,
}) async {
  final source = await showModalBottomSheet<FileUploadSource>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined,
                  color: AppColors.primary),
              title: const Text('Take Picture'),
              onTap: () => Navigator.pop(context, FileUploadSource.camera),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.upload_file_outlined,
                  color: AppColors.primary),
              title: const Text('Upload Files'),
              onTap: () => Navigator.pop(context, FileUploadSource.files),
            ),
          ],
        ),
      ),
    ),
  );

  if (source == null || !context.mounted) return <String>[];

  switch (source) {
    case FileUploadSource.camera:
      final localPath = await Navigator.pushNamed(
        context,
        '/camera-capture',
        arguments:
            requiresLocationForCamera ? const {'requiresLocation': true} : null,
      ) as String?;
      return localPath == null || localPath.trim().isEmpty
          ? <String>[]
          : <String>[localPath.trim()];
    case FileUploadSource.files:
      final result = await FilePicker.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: allowedUploadExtensions,
      );
      if (result == null) return <String>[];
      final paths = result.files
          .map((file) => file.path?.trim() ?? '')
          .where((path) => path.isNotEmpty && _isAllowedUploadPath(path))
          .toList();
      if (paths.length > maxUploadSelectionCount) {
        if (context.mounted) {
          context.showSnack(
            'You can select up to $maxUploadSelectionCount files at a time.',
          );
        }
        return <String>[];
      }
      return paths;
  }
}

bool _isAllowedUploadPath(String path) {
  final cleanPath = path.split('?').first.split('#').first;
  final dotIndex = cleanPath.lastIndexOf('.');
  if (dotIndex < 0 || dotIndex == cleanPath.length - 1) return false;
  final extension = cleanPath.substring(dotIndex + 1).toLowerCase();
  return allowedUploadExtensions.contains(extension);
}
