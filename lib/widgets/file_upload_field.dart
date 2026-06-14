import 'package:flutter/material.dart';

import '../models/api/api_models.dart';
import '../utils/app_colors.dart';
import '../views/tools/files_viewer_screen.dart';

class FileUploadField extends StatelessWidget {
  const FileUploadField({
    super.key,
    required this.field,
    required this.files,
    required this.accentColor,
    required this.isViewMode,
    required this.isUploading,
    required this.hasError,
    this.errorText,
    this.onAddFiles,
  });

  final ApiField field;
  final List<AppFileItem> files;
  final Color accentColor;
  final bool isViewMode;
  final bool isUploading;
  final bool hasError;
  final String? errorText;
  final VoidCallback? onAddFiles;

  bool get _hasFiles => files.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final borderColor = hasError
        ? AppColors.error
        : _hasFiles
            ? accentColor
            : AppColors.light;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_hasFiles) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              field.label,
              style: const TextStyle(
                color: AppColors.textMedium,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openViewer(context),
                  icon: Icon(Icons.visibility_outlined, color: accentColor),
                  label: Text(
                    'View Files',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: accentColor),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    side: BorderSide(color: borderColor, width: 1.5),
                  ),
                ),
              ),
              if (!isViewMode) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isUploading ? null : onAddFiles,
                    icon: isUploading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.add, color: accentColor),
                    label: Text(
                      isUploading ? 'Uploading...' : 'Add more',
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      side: BorderSide(color: borderColor, width: 1.5),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ] else if (isViewMode) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.veryLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.light),
            ),
            child: Row(
              children: [
                Icon(Icons.upload_file_outlined, color: accentColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    field.label,
                    style: const TextStyle(color: AppColors.textMedium),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Text(
                  'No files',
                  style: TextStyle(color: AppColors.textMedium, fontSize: 12),
                ),
              ],
            ),
          ),
        ] else ...[
          OutlinedButton.icon(
            onPressed: isUploading ? null : onAddFiles,
            icon: isUploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.upload_file_outlined, color: accentColor),
            label: Text(
              isUploading ? 'Uploading...' : field.label,
              overflow: TextOverflow.ellipsis,
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              side: BorderSide(color: borderColor),
            ),
          ),
        ],
        if (hasError && errorText != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              errorText!,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _openViewer(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FilesViewerScreen(files: files),
      ),
    );
  }
}
