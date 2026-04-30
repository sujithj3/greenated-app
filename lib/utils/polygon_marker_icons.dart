import 'dart:ui' as ui;
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Generates custom circular marker icons for the polygon editor using
/// [Canvas] → PNG → [BitmapDescriptor.bytes].
///
/// All icons are cached after the first generation so subsequent calls are free.
class PolygonMarkerIcons {
  PolygonMarkerIcons._();

  // ── Cached descriptors ────────────────────────────────────────────────────

  static BitmapDescriptor? _vertex;
  static BitmapDescriptor? _vertexActive;
  static BitmapDescriptor? _vertexFirst;
  static BitmapDescriptor? _midpoint;

  /// Normal vertex: filled green circle with white border.
  static Future<BitmapDescriptor> vertex() async {
    return _vertex ??= await _circle(
      size: 28,
      fill: const ui.Color(0xFF2E7D32),
      border: const ui.Color(0xFFFFFFFF),
      borderWidth: 3,
    );
  }

  /// Active / currently-dragged vertex: larger with accent glow ring.
  static Future<BitmapDescriptor> vertexActive() async {
    return _vertexActive ??= await _circleWithGlow(
      size: 36,
      fill: const ui.Color(0xFF1B5E20),
      border: const ui.Color(0xFFFFFFFF),
      borderWidth: 4,
      glowColor: const ui.Color(0x558BC34A),
      glowWidth: 6,
    );
  }

  /// First vertex marker: darker green so user can identify the polygon start.
  static Future<BitmapDescriptor> vertexFirst() async {
    return _vertexFirst ??= await _circle(
      size: 30,
      fill: const ui.Color(0xFF1B5E20),
      border: const ui.Color(0xFFA5D6A7),
      borderWidth: 3.5,
    );
  }

  /// Midpoint handle: small, semi-transparent gray circle.
  static Future<BitmapDescriptor> midpoint() async {
    return _midpoint ??= await _circle(
      size: 20,
      fill: const ui.Color(0x99BDBDBD),
      border: const ui.Color(0xCCFFFFFF),
      borderWidth: 2,
    );
  }

  /// Pre-warm all icon caches. Call once during [initState].
  static Future<void> preload() async {
    await Future.wait([vertex(), vertexActive(), vertexFirst(), midpoint()]);
  }

  // ── Private drawing helpers ───────────────────────────────────────────────

  /// Draws a filled circle with a border and returns it as a [BitmapDescriptor].
  static Future<BitmapDescriptor> _circle({
    required double size,
    required ui.Color fill,
    required ui.Color border,
    required double borderWidth,
  }) async {
    final double dpr = ui.PlatformDispatcher.instance.views.first.devicePixelRatio;
    final double pxSize = size * dpr;
    final double pxBorder = borderWidth * dpr;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final center = ui.Offset(pxSize / 2, pxSize / 2);
    final radius = (pxSize - pxBorder) / 2;

    // Border
    canvas.drawCircle(
      center,
      radius,
      ui.Paint()
        ..color = border
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = pxBorder
        ..isAntiAlias = true,
    );

    // Fill
    canvas.drawCircle(
      center,
      radius - pxBorder / 2,
      ui.Paint()
        ..color = fill
        ..style = ui.PaintingStyle.fill
        ..isAntiAlias = true,
    );

    final image = await recorder
        .endRecording()
        .toImage(pxSize.ceil(), pxSize.ceil());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      imagePixelRatio: dpr,
    );
  }

  /// Draws a filled circle with an outer glow ring and returns it as a
  /// [BitmapDescriptor].
  static Future<BitmapDescriptor> _circleWithGlow({
    required double size,
    required ui.Color fill,
    required ui.Color border,
    required double borderWidth,
    required ui.Color glowColor,
    required double glowWidth,
  }) async {
    final double dpr = ui.PlatformDispatcher.instance.views.first.devicePixelRatio;
    final double totalSize = size + glowWidth * 2;
    final double pxSize = totalSize * dpr;
    final double pxBorder = borderWidth * dpr;
    final double pxGlow = glowWidth * dpr;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final center = ui.Offset(pxSize / 2, pxSize / 2);
    final innerRadius = (size * dpr - pxBorder) / 2;

    // Glow ring
    canvas.drawCircle(
      center,
      innerRadius + pxBorder / 2 + pxGlow / 2,
      ui.Paint()
        ..color = glowColor
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = pxGlow
        ..isAntiAlias = true,
    );

    // Border
    canvas.drawCircle(
      center,
      innerRadius,
      ui.Paint()
        ..color = border
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = pxBorder
        ..isAntiAlias = true,
    );

    // Fill
    canvas.drawCircle(
      center,
      innerRadius - pxBorder / 2,
      ui.Paint()
        ..color = fill
        ..style = ui.PaintingStyle.fill
        ..isAntiAlias = true,
    );

    final image = await recorder
        .endRecording()
        .toImage(pxSize.ceil(), pxSize.ceil());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      imagePixelRatio: dpr,
    );
  }
}
