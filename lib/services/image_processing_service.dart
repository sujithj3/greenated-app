import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class ImageProcessingService {
  ImageProcessingService({
    Future<Directory> Function()? documentsDirectoryProvider,
  }) : _documentsDirectoryProvider =
            documentsDirectoryProvider ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _documentsDirectoryProvider;

  /// Embeds location and timestamp text into the image at the top-left corner.
  /// Returns the path to the newly saved processed image.
  Future<String> processImage({
    required String originalImagePath,
    required String locationText,
    required String latLngText,
    required String timestampText,
  }) async {
    final directory = await _documentsDirectoryProvider();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final newPath = '${directory.path}/captured_photo_$timestamp.jpg';

    return compute(
      _processImageInBackground,
      _ImageProcessingRequest(
        originalImagePath: originalImagePath,
        outputPath: newPath,
        locationText: locationText,
        latLngText: latLngText,
        timestampText: timestampText,
      ),
      debugLabel: 'processCapturedImage',
    );
  }
}

class _ImageProcessingRequest {
  const _ImageProcessingRequest({
    required this.originalImagePath,
    required this.outputPath,
    required this.locationText,
    required this.latLngText,
    required this.timestampText,
  });

  final String originalImagePath;
  final String outputPath;
  final String locationText;
  final String latLngText;
  final String timestampText;
}

String _processImageInBackground(_ImageProcessingRequest request) {
  final bytes = File(request.originalImagePath).readAsBytesSync();
  img.Image? capturedImage = img.decodeImage(bytes);
  if (capturedImage == null) {
    throw Exception('Failed to decode image');
  }

  capturedImage = img.bakeOrientation(capturedImage);
  capturedImage = _centerCropToPhotoFrame(capturedImage);

  final imageWidth = capturedImage.width;
  final font = imageWidth > 1500 ? img.arial48 : img.arial24;

  const int paddingX = 20;
  const int paddingY = 20;
  const int lineSpacing = 10;

  final maxLineWidth = imageWidth - (paddingX * 2) - 20;
  final overlayLines = [
    _ellipsizeToWidth(request.locationText, font, maxLineWidth),
    if (request.latLngText.isNotEmpty)
      _ellipsizeToWidth(request.latLngText, font, maxLineWidth),
    _ellipsizeToWidth(request.timestampText, font, maxLineWidth),
  ];

  final maxTextWidth = overlayLines
      .map((line) => _calculateTextWidth(line, font))
      .reduce((a, b) => a > b ? a : b);

  final totalTextHeight = (font.lineHeight * overlayLines.length) +
      (lineSpacing * (overlayLines.length - 1));

  img.fillRect(
    capturedImage,
    x1: paddingX - 10,
    y1: paddingY - 10,
    x2: paddingX + maxTextWidth + 10,
    y2: paddingY + totalTextHeight + 10,
    color: img.ColorRgba8(0, 0, 0, 150),
  );

  int currentY = paddingY;
  for (final line in overlayLines) {
    img.drawString(
      capturedImage,
      line,
      font: font,
      x: paddingX,
      y: currentY,
      color: img.ColorRgb8(255, 255, 255),
    );
    currentY += font.lineHeight + lineSpacing;
  }

  final processedBytes = img.encodeJpg(capturedImage, quality: 85);
  File(request.outputPath).writeAsBytesSync(processedBytes);

  return request.outputPath;
}

int _calculateTextWidth(String text, img.BitmapFont font) {
  int width = 0;
  for (int i = 0; i < text.length; i++) {
    final char = text.codeUnitAt(i);
    if (font.characters.containsKey(char)) {
      width += font.characters[char]!.xAdvance;
    }
  }
  return width;
}

String _ellipsizeToWidth(String text, img.BitmapFont font, int maxWidth) {
  if (_calculateTextWidth(text, font) <= maxWidth) {
    return text;
  }

  const ellipsis = '...';
  final ellipsisWidth = _calculateTextWidth(ellipsis, font);
  final buffer = StringBuffer();
  var width = 0;

  for (final codeUnit in text.codeUnits) {
    final characterWidth = font.characters[codeUnit]?.xAdvance ?? 0;
    if (width + characterWidth + ellipsisWidth > maxWidth) {
      break;
    }
    buffer.writeCharCode(codeUnit);
    width += characterWidth;
  }

  return '${buffer.toString()}$ellipsis';
}

img.Image _centerCropToPhotoFrame(img.Image image) {
  final targetAspectRatio = _photoFrameAspectRatioForImageSize(
    width: image.width,
    height: image.height,
  );
  final currentAspectRatio = image.width / image.height;

  var cropWidth = image.width;
  var cropHeight = image.height;

  if (currentAspectRatio > targetAspectRatio) {
    cropWidth = (image.height * targetAspectRatio).round();
  } else if (currentAspectRatio < targetAspectRatio) {
    cropHeight = (image.width / targetAspectRatio).round();
  }

  final cropX = ((image.width - cropWidth) / 2).round();
  final cropY = ((image.height - cropHeight) / 2).round();

  return img.copyCrop(
    image,
    x: cropX,
    y: cropY,
    width: cropWidth,
    height: cropHeight,
  );
}

double _photoFrameAspectRatioForImageSize({
  required int width,
  required int height,
}) {
  const portraitAspectRatio = 3 / 4;
  const landscapeAspectRatio = 4 / 3;
  return width >= height ? landscapeAspectRatio : portraitAspectRatio;
}
