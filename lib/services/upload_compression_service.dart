import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

typedef UploadTempDirectoryProvider = Future<Directory> Function();

enum UploadImageFormat {
  jpeg,
  png,
}

abstract class UploadImageCompressor {
  Future<String?> compress({
    required String sourcePath,
    required String targetPath,
    required int quality,
    required int targetWidth,
    required int targetHeight,
    required UploadImageFormat format,
  });
}

class NativeUploadImageCompressor implements UploadImageCompressor {
  const NativeUploadImageCompressor();

  @override
  Future<String?> compress({
    required String sourcePath,
    required String targetPath,
    required int quality,
    required int targetWidth,
    required int targetHeight,
    required UploadImageFormat format,
  }) async {
    final result = await FlutterImageCompress.compressAndGetFile(
      sourcePath,
      targetPath,
      minWidth: targetWidth,
      minHeight: targetHeight,
      quality: quality,
      format: switch (format) {
        UploadImageFormat.jpeg => CompressFormat.jpeg,
        UploadImageFormat.png => CompressFormat.png,
      },
      autoCorrectionAngle: true,
      keepExif: false,
    );
    return result?.path;
  }
}

class UploadValidationException implements Exception {
  const UploadValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CompressedUploadFile {
  const CompressedUploadFile({
    required this.originalPath,
    required this.path,
    required this.originalSizeBytes,
    required this.sizeBytes,
    required this.extension,
    required this.mimeType,
    required this.isCompressibleImage,
    required this.wasCompressed,
    required this.isTemporary,
    this.quality,
  });

  final String originalPath;
  final String path;
  final int originalSizeBytes;
  final int sizeBytes;
  final String extension;
  final String? mimeType;
  final bool isCompressibleImage;
  final bool wasCompressed;
  final bool isTemporary;
  final int? quality;
}

class UploadValidationResult {
  const UploadValidationResult({
    required this.files,
    required this.totalSizeBytes,
  });

  final List<CompressedUploadFile> files;
  final int totalSizeBytes;

  List<String> get filePaths => files.map((file) => file.path).toList();
}

class UploadCompressionService {
  const UploadCompressionService({
    this.imageCompressor = const NativeUploadImageCompressor(),
    this.tempDirectoryProvider,
    this.uuid = const Uuid(),
  });

  static const int serverUploadLimitBytes = 10000000;
  static const int maxUploadBytes = serverUploadLimitBytes;
  static const int maxImageLongSide = 2048;
  static const List<int> compressionQualities = <int>[85, 75, 65, 55];

  static const String fileTooLargeMessage =
      'Maximum size exceeded. Please remove some files and try again.';
  static const String selectedFilesTooLargeMessage =
      'Maximum size exceeded. Please remove some files and try again.';
  static const String imageCompressionFailedMessage =
      'This image could not be compressed enough. Please choose a smaller image.';

  final UploadImageCompressor imageCompressor;
  final UploadTempDirectoryProvider? tempDirectoryProvider;
  final Uuid uuid;

  Future<UploadValidationResult> prepareSingleFile(String filePath) {
    return prepareFiles(<String>[filePath]);
  }

  Future<UploadValidationResult> prepareFiles(List<String> filePaths) async {
    final infos = <_UploadFileInfo>[];
    for (final path in filePaths) {
      final trimmedPath = path.trim();
      if (trimmedPath.isEmpty) continue;
      infos.add(await _inspectFile(trimmedPath));
    }

    if (infos.isEmpty) {
      throw const UploadValidationException('No files selected.');
    }

    for (final info in infos) {
      if (!info.isCompressibleImage && info.sizeBytes > maxUploadBytes) {
        throw const UploadValidationException(fileTooLargeMessage);
      }
    }

    final originalTotal = _sumSizes(infos.map((info) => info.sizeBytes));
    final shouldReduceBatch = originalTotal > maxUploadBytes;
    final nonCompressibleTotal = _sumSizes(
      infos
          .where((info) => !info.isCompressibleImage)
          .map((info) => info.sizeBytes),
    );
    final compressibleImageTotal = _sumSizes(
      infos
          .where((info) => info.isCompressibleImage)
          .map((info) => info.sizeBytes),
    );

    if (infos.length > 1 &&
        shouldReduceBatch &&
        nonCompressibleTotal >= maxUploadBytes) {
      throw const UploadValidationException(selectedFilesTooLargeMessage);
    }

    final preparedFiles = <CompressedUploadFile>[];
    try {
      for (final info in infos) {
        if (!info.isCompressibleImage) {
          preparedFiles.add(info.toUploadFile());
          continue;
        }

        final targetBytes = _targetBytesForImage(
          info: info,
          isBatchReductionNeeded: shouldReduceBatch,
          nonCompressibleTotal: nonCompressibleTotal,
          compressibleImageTotal: compressibleImageTotal,
        );

        final compressed = await _compressImage(info, targetBytes);
        preparedFiles.add(compressed);
      }

      final totalSize = _sumSizes(preparedFiles.map((file) => file.sizeBytes));
      _debugLog('Upload total size: ${_formatSize(totalSize)}');

      if (totalSize > maxUploadBytes) {
        await _deleteTemporaryFiles(preparedFiles);
        throw const UploadValidationException(selectedFilesTooLargeMessage);
      }

      return UploadValidationResult(
        files: List<CompressedUploadFile>.unmodifiable(preparedFiles),
        totalSizeBytes: totalSize,
      );
    } catch (_) {
      await _deleteTemporaryFiles(preparedFiles);
      rethrow;
    }
  }

  Future<void> cleanupTemporaryFiles(UploadValidationResult result) {
    return _deleteTemporaryFiles(result.files);
  }

  Future<_UploadFileInfo> _inspectFile(String filePath) async {
    final file = File(filePath);
    final sizeBytes = await file.length();
    final extension = _extensionForPath(filePath);
    final headerBytes = await _readHeaderBytes(file);
    final mimeType = lookupMimeType(filePath, headerBytes: headerBytes);
    return _UploadFileInfo(
      path: filePath,
      sizeBytes: sizeBytes,
      extension: extension,
      mimeType: mimeType,
    );
  }

  Future<CompressedUploadFile> _compressImage(
    _UploadFileInfo info,
    int targetBytes,
  ) async {
    final outputFormat = await _outputFormatFor(info);
    final outputExtension =
        outputFormat == UploadImageFormat.jpeg ? 'jpg' : 'png';
    final dimensions = await _targetDimensionsFor(info);
    final candidatePaths = <String>{};
    CompressedUploadFile? bestCandidate;

    for (final quality in compressionQualities) {
      final targetPath = await _newTemporaryPath(outputExtension);
      candidatePaths.add(targetPath);

      String? compressedPath;
      try {
        compressedPath = await imageCompressor.compress(
          sourcePath: info.path,
          targetPath: targetPath,
          quality: quality,
          targetWidth: dimensions.width,
          targetHeight: dimensions.height,
          format: outputFormat,
        );
      } on UnsupportedError catch (error) {
        _debugLog('Image compression unsupported: $error');
      } catch (error) {
        _debugLog('Image compression failed: $error');
      }

      if (compressedPath == null || compressedPath.trim().isEmpty) {
        continue;
      }

      candidatePaths.add(compressedPath);
      final compressedFile = File(compressedPath);
      if (!await compressedFile.exists()) continue;

      final compressedSize = await compressedFile.length();
      final candidate = CompressedUploadFile(
        originalPath: info.path,
        path: compressedPath,
        originalSizeBytes: info.sizeBytes,
        sizeBytes: compressedSize,
        extension: outputExtension,
        mimeType:
            outputFormat == UploadImageFormat.jpeg ? 'image/jpeg' : 'image/png',
        isCompressibleImage: true,
        wasCompressed: true,
        isTemporary: true,
        quality: quality,
      );
      _logFileResult(candidate);

      if (bestCandidate == null || compressedSize < bestCandidate.sizeBytes) {
        bestCandidate = candidate;
      }

      if (compressedSize <= targetBytes) break;
    }

    for (final path in candidatePaths) {
      if (path != bestCandidate?.path) {
        await _deleteFileQuietly(path);
      }
    }

    if (bestCandidate == null) {
      throw const UploadValidationException(imageCompressionFailedMessage);
    }

    if (bestCandidate.sizeBytes >= info.sizeBytes) {
      await _deleteFileQuietly(bestCandidate.path);
      final original = info.toUploadFile();
      _logFileResult(original);
      return original;
    }

    return bestCandidate;
  }

  int _targetBytesForImage({
    required _UploadFileInfo info,
    required bool isBatchReductionNeeded,
    required int nonCompressibleTotal,
    required int compressibleImageTotal,
  }) {
    if (!isBatchReductionNeeded || compressibleImageTotal <= 0) {
      return maxUploadBytes;
    }

    final imageBudget = maxUploadBytes - nonCompressibleTotal;
    if (imageBudget <= 0) return 1;

    final proportionalTarget =
        (imageBudget * info.sizeBytes / compressibleImageTotal).floor();
    return math.max(1, proportionalTarget);
  }

  Future<UploadImageFormat> _outputFormatFor(_UploadFileInfo info) async {
    if (info.extension != 'png') return UploadImageFormat.jpeg;

    final transparency = await _detectPngTransparency(info.path);
    if (transparency == _PngTransparency.opaque) {
      return UploadImageFormat.jpeg;
    }

    return UploadImageFormat.png;
  }

  Future<_ImageDimensions> _targetDimensionsFor(_UploadFileInfo info) async {
    final bytes = await File(info.path).readAsBytes();
    final dimensions = await compute(_decodeImageDimensions, bytes);
    if (dimensions == null) {
      return const _ImageDimensions(maxImageLongSide, maxImageLongSide);
    }

    final width = dimensions.width;
    final height = dimensions.height;
    final longSide = math.max(width, height);
    if (longSide <= maxImageLongSide) {
      return _ImageDimensions(width, height);
    }

    final scale = maxImageLongSide / longSide;
    return _ImageDimensions(
      math.max(1, (width * scale).round()),
      math.max(1, (height * scale).round()),
    );
  }

  Future<_PngTransparency> _detectPngTransparency(String path) async {
    try {
      final transparencyValue = await compute(
        _detectPngTransparencyValue,
        await File(path).readAsBytes(),
      );
      return _PngTransparency.values[transparencyValue];
    } catch (_) {
      return _PngTransparency.unknown;
    }
  }

  Future<String> _newTemporaryPath(String extension) async {
    final directory = await (tempDirectoryProvider ?? getTemporaryDirectory)();
    return '${directory.path}/upload_${uuid.v4()}.$extension';
  }

  Future<void> _deleteTemporaryFiles(
      Iterable<CompressedUploadFile> files) async {
    for (final file in files) {
      if (file.isTemporary) {
        await _deleteFileQuietly(file.path);
      }
    }
  }

  Future<void> _deleteFileQuietly(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Best-effort cleanup only.
    }
  }

  Future<List<int>?> _readHeaderBytes(File file) async {
    try {
      final length = await file.length();
      if (length == 0) return null;
      final stream = file.openRead(0, math.min(512, length));
      final bytes = <int>[];
      await for (final chunk in stream) {
        bytes.addAll(chunk);
      }
      return bytes;
    } catch (_) {
      return null;
    }
  }

  void _logFileResult(CompressedUploadFile file) {
    final resultLabel = file.wasCompressed ? 'compressed' : 'final';
    _debugLog(
      'Upload file: ext=${file.extension}, mime=${file.mimeType ?? 'unknown'}, '
      'original=${_formatSize(file.originalSizeBytes)}, '
      '$resultLabel=${_formatSize(file.sizeBytes)}, '
      'compressed=${file.wasCompressed}, quality=${file.quality ?? 'n/a'}',
    );
  }

  void _debugLog(String message) {
    if (!kDebugMode) return;
    debugPrint(message);
  }

  int _sumSizes(Iterable<int> sizes) {
    var total = 0;
    for (final size in sizes) {
      total += size;
    }
    return total;
  }

  String _formatSize(int bytes) {
    const kb = 1000;
    const mb = 1000 * 1000;
    if (bytes >= mb) {
      final value = bytes / mb;
      return '${_formatSizeValue(value)} MB ($bytes bytes)';
    }
    if (bytes >= kb) {
      final value = bytes / kb;
      return '${_formatSizeValue(value)} KB ($bytes bytes)';
    }
    return '$bytes bytes';
  }

  String _formatSizeValue(double value) {
    if (value >= 10 || value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }

  String _extensionForPath(String path) {
    final cleanPath = path.split('?').first.split('#').first;
    final dotIndex = cleanPath.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex == cleanPath.length - 1) return '';
    return cleanPath.substring(dotIndex + 1).toLowerCase();
  }
}

class _UploadFileInfo {
  const _UploadFileInfo({
    required this.path,
    required this.sizeBytes,
    required this.extension,
    required this.mimeType,
  });

  static const Set<String> _compressibleImageExtensions = <String>{
    'jpg',
    'jpeg',
    'png',
    'heic',
    'heif',
  };

  static const Set<String> _documentExtensions = <String>{
    'pdf',
    'doc',
    'docx',
    'txt',
  };

  static const Set<String> _compressibleImageMimeTypes = <String>{
    'image/jpeg',
    'image/png',
    'image/heic',
    'image/heif',
    'image/heic-sequence',
    'image/heif-sequence',
  };

  final String path;
  final int sizeBytes;
  final String extension;
  final String? mimeType;

  bool get isCompressibleImage {
    if (_documentExtensions.contains(extension)) return false;
    if (_compressibleImageExtensions.contains(extension)) return true;
    return mimeType != null && _compressibleImageMimeTypes.contains(mimeType);
  }

  CompressedUploadFile toUploadFile() {
    return CompressedUploadFile(
      originalPath: path,
      path: path,
      originalSizeBytes: sizeBytes,
      sizeBytes: sizeBytes,
      extension: extension,
      mimeType: mimeType,
      isCompressibleImage: isCompressibleImage,
      wasCompressed: false,
      isTemporary: false,
    );
  }
}

class _ImageDimensions {
  const _ImageDimensions(this.width, this.height);

  final int width;
  final int height;
}

enum _PngTransparency {
  opaque,
  hasTransparency,
  unknown,
}

_ImageDimensions? _decodeImageDimensions(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  if (image == null) return null;
  return _ImageDimensions(image.width, image.height);
}

int _detectPngTransparencyValue(Uint8List bytes) {
  final image = img.decodePng(bytes);
  if (image == null) return _PngTransparency.unknown.index;
  if (!image.hasAlpha) return _PngTransparency.opaque.index;

  for (final pixel in image) {
    if (pixel.a < pixel.maxChannelValue) {
      return _PngTransparency.hasTransparency.index;
    }
  }
  return _PngTransparency.opaque.index;
}
