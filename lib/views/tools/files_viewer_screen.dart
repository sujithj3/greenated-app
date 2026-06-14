import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/api/api_models.dart';
import '../../utils/app_colors.dart';
import '../../utils/snack_bar_helper.dart';

IconData _iconFor(AppFileItem file) {
  if (file.isPdf) return Icons.picture_as_pdf_outlined;
  if (file.isDoc || file.isDocx) return Icons.description_outlined;
  if (file.isTxt) return Icons.article_outlined;
  if (file.isImage) return Icons.image_outlined;
  return Icons.insert_drive_file_outlined;
}

class FilesViewerScreen extends StatefulWidget {
  const FilesViewerScreen({
    super.key,
    required this.files,
    this.initialIndex = 0,
  });

  final List<AppFileItem> files;
  final int initialIndex;

  @override
  State<FilesViewerScreen> createState() => _FilesViewerScreenState();
}

class _FilesViewerScreenState extends State<FilesViewerScreen> {
  static const double _previewPadding = 12;
  static const double _thumbnailSize = 56;
  static const double _thumbnailSpacing = 6;
  static const double _thumbnailHorizontalPadding = 12;

  late int _selectedIndex;
  final ScrollController _thumbnailScrollController = ScrollController();
  bool _isDownloading = false;

  AppFileItem get _selectedFile => widget.files[_selectedIndex];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.files.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.files.length - 1).toInt();
    _scrollSelectedThumbnail();
  }

  @override
  void dispose() {
    _thumbnailScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.files.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Files')),
        body: const Center(
          child: Text(
            'No files',
            style: TextStyle(color: AppColors.textMedium),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Files'),
        actions: [
          IconButton(
            tooltip: 'Download',
            onPressed: _isDownloading ? null : _downloadSelected,
            icon: _isDownloading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.file_download_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(_previewPadding),
                    child: _buildPreview(_selectedFile),
                  ),
                ],
              ),
            ),
            _buildThumbnails(),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(AppFileItem file) {
    if (file.isImage) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openImageViewer(file),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            color: Colors.black,
            child: file.localPath != null
                ? Image.file(
                    File(file.localPath!),
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _fallback(file),
                  )
                : CachedNetworkImage(
                    imageUrl: file.url ?? '',
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                    errorWidget: (_, __, ___) => _fallback(file),
                  ),
          ),
        ),
      );
    }

    if (file.isTxt) {
      return _TxtPreview(file: file);
    }

    if (file.isPdf) {
      return _PdfPreview(
        key: ValueKey(
          'pdf_${file.localPath ?? file.url ?? file.id ?? file.displayName}',
        ),
        file: file,
        isDownloading: _isDownloading,
        onDownload: _downloadSelected,
      );
    }

    return _fallback(file);
  }

  Widget _fallback(
    AppFileItem file, {
    String message = 'Preview not available',
  }) {
    return _FileFallback(
      file: file,
      message: message,
      isDownloading: _isDownloading,
      onDownload: _downloadSelected,
    );
  }

  Widget _buildThumbnails() {
    return Container(
      height: 96,
      padding: const EdgeInsets.only(top: 8, bottom: 28),
      color: AppColors.white,
      child: ListView.separated(
        controller: _thumbnailScrollController,
        padding:
            const EdgeInsets.symmetric(horizontal: _thumbnailHorizontalPadding),
        scrollDirection: Axis.horizontal,
        itemCount: widget.files.length,
        separatorBuilder: (_, __) => const SizedBox(width: _thumbnailSpacing),
        itemBuilder: (_, index) {
          final file = widget.files[index];
          final isSelected = index == _selectedIndex;
          return GestureDetector(
            onTap: () => _selectFile(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: _thumbnailSize,
              height: _thumbnailSize,
              decoration: BoxDecoration(
                color: AppColors.veryLight,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.divider,
                  width: isSelected ? 2 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: file.isImage
                  ? _thumbnailImage(file)
                  : Icon(_iconFor(file), color: AppColors.primary, size: 30),
            ),
          );
        },
      ),
    );
  }

  Widget _thumbnailImage(AppFileItem file) {
    if (file.localPath != null) {
      return Image.file(
        File(file.localPath!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            Icon(_iconFor(file), color: AppColors.primary),
      );
    }
    return CachedNetworkImage(
      imageUrl: file.url ?? '',
      fit: BoxFit.cover,
      errorWidget: (_, __, ___) =>
          Icon(_iconFor(file), color: AppColors.primary),
    );
  }

  void _selectFile(int index) {
    if (widget.files.isEmpty) return;
    final nextIndex = index.clamp(0, widget.files.length - 1).toInt();
    if (nextIndex == _selectedIndex) {
      _scrollSelectedThumbnail();
      return;
    }
    setState(() => _selectedIndex = nextIndex);
    _scrollSelectedThumbnail();
  }

  void _scrollSelectedThumbnail() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_thumbnailScrollController.hasClients) return;
      final position = _thumbnailScrollController.position;
      final itemCenter = _thumbnailHorizontalPadding +
          (_selectedIndex * (_thumbnailSize + _thumbnailSpacing)) +
          (_thumbnailSize / 2);
      final targetOffset = (itemCenter - (position.viewportDimension / 2))
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();

      if ((position.pixels - targetOffset).abs() < 1) return;
      _thumbnailScrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _openImageViewer(AppFileItem file) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenImageViewer(file: file),
      ),
    );
  }

  Future<void> _downloadSelected() async {
    final file = _selectedFile;
    setState(() => _isDownloading = true);
    try {
      final xFile = await _materializeFile(file);
      if (!mounted) return;
      context.showSnack('File ready', success: true);
      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        <XFile>[xFile],
        subject: file.displayName,
        sharePositionOrigin:
            box != null ? box.localToGlobal(Offset.zero) & box.size : null,
      );
    } catch (e) {
      if (mounted) {
        context.showSnack('Unable to download file. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<XFile> _materializeFile(AppFileItem file) async {
    if (file.localPath != null) return XFile(file.localPath!);
    final url = file.url;
    if (url == null || url.isEmpty) {
      throw StateError('No file URL available.');
    }
    final response = await http.get(Uri.parse(url));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Download failed.');
    }
    final dir = await getApplicationDocumentsDirectory();
    final savedFile = File('${dir.path}/${_safeFileName(file.displayName)}');
    await savedFile.writeAsBytes(response.bodyBytes);
    return XFile(savedFile.path);
  }

  String _safeFileName(String value) {
    final cleaned = value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return cleaned.isEmpty ? 'file' : cleaned;
  }
}

class _FileFallback extends StatelessWidget {
  const _FileFallback({
    required this.file,
    required this.message,
    required this.isDownloading,
    required this.onDownload,
  });

  final AppFileItem file;
  final String message;
  final bool isDownloading;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.light),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_iconFor(file), size: 64, color: AppColors.primary),
          const SizedBox(height: 16),
          Text(
            file.displayName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMedium),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: isDownloading ? null : onDownload,
            icon: const Icon(Icons.file_download_outlined),
            label: const Text('Download'),
          ),
        ],
      ),
    );
  }
}

class _PdfPreview extends StatefulWidget {
  const _PdfPreview({
    super.key,
    required this.file,
    required this.isDownloading,
    required this.onDownload,
  });

  final AppFileItem file;
  final bool isDownloading;
  final VoidCallback onDownload;

  @override
  State<_PdfPreview> createState() => _PdfPreviewState();
}

class _PdfPreviewState extends State<_PdfPreview> {
  int _passwordPromptCount = 0;
  bool _passwordDialogCancelled = false;

  @override
  void didUpdateWidget(covariant _PdfPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_sourceKey(oldWidget.file) != _sourceKey(widget.file)) {
      _passwordPromptCount = 0;
      _passwordDialogCancelled = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewer = _buildPdfViewer();
    if (viewer == null) {
      return _buildFallback();
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.light),
      ),
      clipBehavior: Clip.antiAlias,
      child: viewer,
    );
  }

  Widget? _buildPdfViewer() {
    final params = PdfViewerParams(
      backgroundColor: AppColors.white,
      loadingBannerBuilder: (_, __, ___) => const Center(
        child: CircularProgressIndicator(),
      ),
      errorBannerBuilder: (context, error, stackTrace, documentRef) {
        return _buildFallback(message: _messageForError(error));
      },
    );

    if (widget.file.localPath != null) {
      return PdfViewer.file(
        widget.file.localPath!,
        passwordProvider: _showPasswordDialog,
        params: params,
      );
    }

    final uri = Uri.tryParse(widget.file.url ?? '');
    if (uri == null ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }

    return PdfViewer.uri(
      uri,
      passwordProvider: _showPasswordDialog,
      params: params,
    );
  }

  Widget _buildFallback({String message = 'Preview not available'}) {
    return _FileFallback(
      file: widget.file,
      message: message,
      isDownloading: widget.isDownloading,
      onDownload: widget.onDownload,
    );
  }

  Future<String?> _showPasswordDialog() async {
    if (!mounted) return null;

    final textController = TextEditingController();
    final showInvalidMessage = _passwordPromptCount > 0;
    _passwordPromptCount += 1;
    _passwordDialogCancelled = false;

    try {
      final password = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Enter PDF password'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.file.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMedium,
                    fontSize: 13,
                  ),
                ),
                if (showInvalidMessage) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Incorrect password. Try again.',
                    style: TextStyle(color: AppColors.error, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: textController,
                  autofocus: true,
                  keyboardType: TextInputType.visiblePassword,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (value) =>
                      Navigator.of(dialogContext).pop(value),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(null),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(textController.text),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

      if (password == null) {
        _passwordDialogCancelled = true;
      }
      return password;
    } finally {
      textController.dispose();
    }
  }

  String _messageForError(Object error) {
    if (_passwordDialogCancelled || error is PdfPasswordException) {
      return 'Password is required to preview this PDF.';
    }
    return 'Preview not available';
  }

  String _sourceKey(AppFileItem file) =>
      file.localPath ?? file.url ?? file.id ?? file.displayName;
}

class _TxtPreview extends StatelessWidget {
  const _TxtPreview({required this.file});

  final AppFileItem file;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _loadText(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || (snapshot.data ?? '').isEmpty) {
          return _TxtFallback(file: file);
        }
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.light),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              snapshot.data!,
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        );
      },
    );
  }

  Future<String> _loadText() async {
    if (file.localPath != null) {
      return File(file.localPath!).readAsString();
    }
    final url = file.url;
    if (url == null || url.isEmpty) return '';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode < 200 || response.statusCode >= 300) return '';
    return response.body;
  }
}

class _TxtFallback extends StatelessWidget {
  const _TxtFallback({required this.file});

  final AppFileItem file;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.light),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.article_outlined,
              size: 64, color: AppColors.primary),
          const SizedBox(height: 16),
          Text(
            file.displayName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Preview not available',
            style: TextStyle(color: AppColors.textMedium),
          ),
        ],
      ),
    );
  }
}

class _FullScreenImageViewer extends StatelessWidget {
  const _FullScreenImageViewer({required this.file});

  final AppFileItem file;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          file.displayName,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child: _buildImage(),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (file.localPath != null) {
      return Image.file(
        File(file.localPath!),
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _buildError(),
      );
    }
    return CachedNetworkImage(
      imageUrl: file.url ?? '',
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.contain,
      placeholder: (_, __) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
      errorWidget: (_, __, ___) => _buildError(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.broken_image_outlined,
            color: Colors.white70,
            size: 56,
          ),
          const SizedBox(height: 12),
          Text(
            file.displayName,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
