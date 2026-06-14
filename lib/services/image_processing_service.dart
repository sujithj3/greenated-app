import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../utils/camera_photo_frame.dart';

class ImageProcessingService {
  /// Embeds location and timestamp text into the image at the top-left corner.
  /// Returns the path to the newly saved processed image.
  Future<String> processImage({
    required String originalImagePath,
    required String locationText,
    required String latLngText,
    required String timestampText,
  }) async {
    // Read the image file
    final bytes = await File(originalImagePath).readAsBytes();

    // Decode the image
    img.Image? capturedImage = img.decodeImage(bytes);
    if (capturedImage == null) {
      throw Exception('Failed to decode image');
    }
    capturedImage = img.bakeOrientation(capturedImage);
    capturedImage = _centerCropToPhotoFrame(capturedImage);

    // Determine font size and padding based on image width to scale appropriately
    final imageWidth = capturedImage.width;
    final font = imageWidth > 1500 ? img.arial48 : img.arial24;

    // Define exact positions and dimensions
    const int paddingX = 20;
    const int paddingY = 20;
    const int lineSpacing = 10;

    final maxLineWidth = imageWidth - (paddingX * 2) - 20;
    final overlayLines = [
      _ellipsizeToWidth(locationText, font, maxLineWidth),
      if (latLngText.isNotEmpty)
        _ellipsizeToWidth(latLngText, font, maxLineWidth),
      _ellipsizeToWidth(timestampText, font, maxLineWidth),
    ];

    final maxTextWidth = overlayLines
        .map((line) => _calculateTextWidth(line, font))
        .reduce((a, b) => a > b ? a : b);

    final totalTextHeight = (font.lineHeight * overlayLines.length) +
        (lineSpacing * (overlayLines.length - 1));

    // Draw a semi-transparent dark background for the text
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

    // Re-encode near the original camera quality after adding the overlay.
    final processedBytes = img.encodeJpg(capturedImage, quality: 85);

    // Save to a new file in documents directory
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final newPath = '${directory.path}/captured_photo_$timestamp.jpg';

    final outFile = File(newPath);
    await outFile.writeAsBytes(processedBytes);

    return newPath;
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
    final targetAspectRatio = CameraPhotoFrame.aspectRatioForImageSize(
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
}
