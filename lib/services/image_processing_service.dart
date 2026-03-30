import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

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

    // Determine font size and padding based on image width to scale appropriately
    final imageWidth = capturedImage.width;
    final font = imageWidth > 1500 ? img.arial48 : img.arial24;
    
    // Define exact positions and dimensions
    const int paddingX = 20;
    const int paddingY = 20;
    const int lineSpacing = 10;
    
    // Calculate text bounds
    final locationWidth = _calculateTextWidth(locationText, font);
    final latLngWidth = _calculateTextWidth(latLngText, font);
    final timestampWidth = _calculateTextWidth(timestampText, font);
    
    final maxTextWidth = [locationWidth, latLngWidth, timestampWidth]
      .reduce((a, b) => a > b ? a : b);
    
    final totalTextHeight = (font.lineHeight * 3) + (lineSpacing * 2);

    // Draw a semi-transparent dark background for the text
    img.fillRect(
      capturedImage,
      x1: paddingX - 10,
      y1: paddingY - 10,
      x2: paddingX + maxTextWidth + 10,
      y2: paddingY + totalTextHeight + 10,
      color: img.ColorRgba8(0, 0, 0, 150),
    );

    // Draw lines
    int currentY = paddingY;

    // Line 1: Location
    img.drawString(
      capturedImage,
      locationText,
      font: font,
      x: paddingX,
      y: currentY,
      color: img.ColorRgb8(255, 255, 255),
    );
    currentY += font.lineHeight + lineSpacing;

    // Line 2: Lat/Lng
    img.drawString(
      capturedImage,
      latLngText,
      font: font,
      x: paddingX,
      y: currentY,
      color: img.ColorRgb8(255, 255, 255),
    );
    currentY += font.lineHeight + lineSpacing;

    // Line 3: Timestamp
    img.drawString(
      capturedImage,
      timestampText,
      font: font,
      x: paddingX,
      y: currentY,
      color: img.ColorRgb8(255, 255, 255),
    );

    // Compress and encode
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
}
