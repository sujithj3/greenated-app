import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:greenated/services/upload_compression_service.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('upload_compression_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  UploadCompressionService serviceWith(FakeUploadImageCompressor compressor) {
    return UploadCompressionService(
      imageCompressor: compressor,
      tempDirectoryProvider: () async => tempDir,
    );
  }

  test('rejects single oversized PDF and DOCX files', () async {
    final compressor = FakeUploadImageCompressor();
    final service = serviceWith(compressor);

    for (final extension in <String>['pdf', 'docx']) {
      final file = await _createFile(
        tempDir,
        'oversized.$extension',
        UploadCompressionService.maxUploadBytes + 1,
      );

      await expectLater(
        service.prepareSingleFile(file.path),
        throwsA(
          isA<UploadValidationException>().having(
            (error) => error.message,
            'message',
            UploadCompressionService.fileTooLargeMessage,
          ),
        ),
      );
    }

    expect(compressor.calls, isEmpty);
  });

  test('compresses images in mixed uploads and leaves documents unchanged',
      () async {
    final compressor = FakeUploadImageCompressor(outputSizeBytes: 300000);
    final service = serviceWith(compressor);
    final image = await _createFile(tempDir, 'image.jpg', 800000);
    final pdf = await _createFile(tempDir, 'document.pdf', 700000);
    final docx = await _createFile(tempDir, 'document.docx', 600000);

    final result = await service.prepareFiles(
      <String>[image.path, pdf.path, docx.path],
    );

    expect(result.filePaths.first, isNot(image.path));
    expect(result.filePaths.skip(1).toList(), <String>[pdf.path, docx.path]);
    expect(result.totalSizeBytes, 1600000);
    expect(compressor.calls, hasLength(1));
    expect(compressor.calls.single.sourcePath, image.path);
  });

  test('compresses small images under the server limit', () async {
    final compressor = FakeUploadImageCompressor(outputSizeBytes: 400000);
    final service = serviceWith(compressor);
    final image = await _createFile(tempDir, 'small.jpg', 800000);

    final result = await service.prepareSingleFile(image.path);

    expect(result.filePaths.single, isNot(image.path));
    expect(result.totalSizeBytes, 400000);
    expect(result.files.single.wasCompressed, isTrue);
    expect(compressor.calls, hasLength(1));
    expect(compressor.calls.single.sourcePath, image.path);
  });

  test('uses the original image when compression output is larger', () async {
    final compressor = FakeUploadImageCompressor(outputSizeBytes: 900000);
    final service = serviceWith(compressor);
    final image = await _createFile(tempDir, 'optimized.jpg', 800000);

    final result = await service.prepareSingleFile(image.path);

    expect(result.filePaths.single, image.path);
    expect(result.totalSizeBytes, 800000);
    expect(result.files.single.wasCompressed, isFalse);
    expect(compressor.calls, hasLength(1));
  });

  test('rejects mixed uploads when a non-image document exceeds the limit',
      () async {
    final compressor = FakeUploadImageCompressor();
    final service = serviceWith(compressor);
    final image = await _createFile(tempDir, 'image.jpg', 100000);
    final docx = await _createFile(
      tempDir,
      'oversized.docx',
      UploadCompressionService.maxUploadBytes + 1,
    );

    await expectLater(
      service.prepareFiles(<String>[image.path, docx.path]),
      throwsA(
        isA<UploadValidationException>().having(
          (error) => error.message,
          'message',
          UploadCompressionService.fileTooLargeMessage,
        ),
      ),
    );

    expect(compressor.calls, isEmpty);
  });

  test('rejects multiple compressed images when final total exceeds limit',
      () async {
    final compressor = FakeUploadImageCompressor(outputSizeBytes: 5100000);
    final service = serviceWith(compressor);
    final first = await _createFile(tempDir, 'first.jpg', 8000000);
    final second = await _createFile(tempDir, 'second.jpg', 8000000);

    await expectLater(
      service.prepareFiles(<String>[first.path, second.path]),
      throwsA(
        isA<UploadValidationException>().having(
          (error) => error.message,
          'message',
          UploadCompressionService.selectedFilesTooLargeMessage,
        ),
      ),
    );

    expect(compressor.calls, hasLength(8));
  });

  test('rejects a compressed image when its final size exceeds the limit',
      () async {
    final compressor = FakeUploadImageCompressor(
      outputSizeBytes: UploadCompressionService.maxUploadBytes + 500000,
    );
    final service = serviceWith(compressor);
    final image = await _createFile(
      tempDir,
      'still-too-large.jpg',
      UploadCompressionService.maxUploadBytes + 1000000,
    );

    await expectLater(
      service.prepareSingleFile(image.path),
      throwsA(
        isA<UploadValidationException>().having(
          (error) => error.message,
          'message',
          UploadCompressionService.selectedFilesTooLargeMessage,
        ),
      ),
    );

    expect(compressor.calls, hasLength(4));
  });

  test('maps image compression failure to the image-specific message',
      () async {
    final compressor = FakeUploadImageCompressor(returnNull: true);
    final service = serviceWith(compressor);
    final image = await _createFile(
      tempDir,
      'oversized.jpg',
      UploadCompressionService.maxUploadBytes + 1,
    );

    await expectLater(
      service.prepareSingleFile(image.path),
      throwsA(
        isA<UploadValidationException>().having(
          (error) => error.message,
          'message',
          UploadCompressionService.imageCompressionFailedMessage,
        ),
      ),
    );

    expect(compressor.calls, hasLength(4));
  });

  test('does not pass documents to the image compressor', () async {
    final compressor = FakeUploadImageCompressor(outputSizeBytes: 1000000);
    final service = serviceWith(compressor);
    final pdf = await _createFile(tempDir, 'small.pdf', 1000000);
    final doc = await _createFile(tempDir, 'small.doc', 1000000);
    final docx = await _createFile(tempDir, 'small.docx', 1000000);
    final txt = await _createFile(tempDir, 'small.txt', 1000000);

    final result = await service.prepareFiles(
      <String>[pdf.path, doc.path, docx.path, txt.path],
    );

    expect(result.totalSizeBytes, 4000000);
    expect(compressor.calls, isEmpty);
  });
}

Future<File> _createFile(
  Directory directory,
  String name,
  int sizeBytes,
) async {
  final file = File('${directory.path}/$name');
  await file.writeAsBytes(Uint8List(sizeBytes), flush: true);
  return file;
}

class FakeUploadImageCompressor implements UploadImageCompressor {
  FakeUploadImageCompressor({
    this.outputSizeBytes = 0,
    this.returnNull = false,
  });

  final int outputSizeBytes;
  final bool returnNull;
  final List<FakeCompressionCall> calls = <FakeCompressionCall>[];

  @override
  Future<String?> compress({
    required String sourcePath,
    required String targetPath,
    required int quality,
    required int targetWidth,
    required int targetHeight,
    required UploadImageFormat format,
  }) async {
    calls.add(
      FakeCompressionCall(
        sourcePath: sourcePath,
        quality: quality,
        format: format,
      ),
    );

    if (returnNull) return null;

    await File(targetPath).writeAsBytes(
      Uint8List(math.max(0, outputSizeBytes)),
      flush: true,
    );
    return targetPath;
  }
}

class FakeCompressionCall {
  const FakeCompressionCall({
    required this.sourcePath,
    required this.quality,
    required this.format,
  });

  final String sourcePath;
  final int quality;
  final UploadImageFormat format;
}
