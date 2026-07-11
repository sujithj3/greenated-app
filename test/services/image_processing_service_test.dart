import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:greenated/services/image_processing_service.dart';
import 'package:image/image.dart' as img;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Directory documentsDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('image_processing_test_');
    documentsDir = Directory('${tempDir.path}/documents');
    await documentsDir.create();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  ImageProcessingService service() {
    return ImageProcessingService(
      documentsDirectoryProvider: () async => documentsDir,
    );
  }

  test('creates a processed jpg in the documents directory', () async {
    final inputFile = await _createJpg(tempDir, 'input.jpg', 900, 1200);

    final outputPath = await service().processImage(
      originalImagePath: inputFile.path,
      locationText: 'GPS location captured',
      latLngText: 'Lat: 10.000000, Lng: 76.000000',
      timestampText: '18 Jun 2026, 10:30 AM IST',
    );

    final outputFile = File(outputPath);
    final outputBytes = await outputFile.readAsBytes();

    expect(outputPath, startsWith('${documentsDir.path}/captured_photo_'));
    expect(outputPath, endsWith('.jpg'));
    expect(await outputFile.exists(), isTrue);
    expect(_hasJpgSignature(outputBytes), isTrue);
    expect(img.decodeJpg(outputBytes), isNotNull);
  });

  test('crops portrait images to the camera photo frame', () async {
    final inputFile = await _createJpg(tempDir, 'portrait.jpg', 900, 1600);

    final outputImage = await _processAndDecode(
      service(),
      inputFile.path,
    );

    expect(outputImage.width, 900);
    expect(outputImage.height, 1200);
  });

  test('crops landscape images to the camera photo frame', () async {
    final inputFile = await _createJpg(tempDir, 'landscape.jpg', 1600, 900);

    final outputImage = await _processAndDecode(
      service(),
      inputFile.path,
    );

    expect(outputImage.width, 1200);
    expect(outputImage.height, 900);
  });

  test('throws when the source file is not a valid image', () async {
    final invalidFile = File('${tempDir.path}/invalid.jpg');
    await invalidFile.writeAsBytes(<int>[1, 2, 3, 4], flush: true);

    await expectLater(
      service().processImage(
        originalImagePath: invalidFile.path,
        locationText: 'GPS location captured',
        latLngText: '',
        timestampText: '18 Jun 2026, 10:30 AM IST',
      ),
      throwsException,
    );
  });
}

Future<File> _createJpg(
  Directory directory,
  String name,
  int width,
  int height,
) async {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(90, 130, 180));

  final file = File('${directory.path}/$name');
  await file.writeAsBytes(img.encodeJpg(image, quality: 90), flush: true);
  return file;
}

Future<img.Image> _processAndDecode(
  ImageProcessingService service,
  String inputPath,
) async {
  final outputPath = await service.processImage(
    originalImagePath: inputPath,
    locationText: 'GPS location captured',
    latLngText: '',
    timestampText: '18 Jun 2026, 10:30 AM IST',
  );
  final outputBytes = await File(outputPath).readAsBytes();
  final outputImage = img.decodeJpg(outputBytes);

  expect(outputImage, isNotNull);
  return outputImage!;
}

bool _hasJpgSignature(Uint8List bytes) {
  return bytes.length >= 4 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[bytes.length - 2] == 0xff &&
      bytes[bytes.length - 1] == 0xd9;
}
