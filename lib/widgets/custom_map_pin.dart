import 'package:flutter/material.dart';

/// A reusable custom map pin marker widget.
///
/// It draws a soft teardrop/pin shape programmatically using [CustomPainter]
/// with smooth Bezier curves and places an icon inside the circular area.
class CustomMapPin extends StatelessWidget {
  static const Color referencePinColor = Color(0xFFE95B4F);

  final double width;
  final double height;
  final Color pinColor;
  final String iconAsset;
  final double iconSize;
  final bool isUpsideDown;

  const CustomMapPin({
    super.key,
    this.width = 72,
    this.height = 96,
    this.pinColor = referencePinColor,
    this.iconAsset = 'assets/images/four-way-arrow.png',
    this.iconSize = 40,
    this.isUpsideDown = false,
  });

  @override
  Widget build(BuildContext context) {
    final double circleCenterY =
        isUpsideDown ? height - (width / 2) : width / 2;
    final double visualCenterY =
        isUpsideDown ? circleCenterY + 4 : circleCenterY - 4;

    Widget paintWidget = CustomPaint(
      size: Size(width, height),
      painter: _MapPinPainter(
        color: pinColor.withValues(alpha: 0.45),
      ),
    );

    if (isUpsideDown) {
      paintWidget = Transform.flip(
        flipY: true,
        child: paintWidget,
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          paintWidget,
          Positioned(
            top: visualCenterY - (iconSize / 2),
            child: Image.asset(
              iconAsset,
              width: iconSize,
              height: iconSize,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPinPainter extends CustomPainter {
  final Color color;

  _MapPinPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..cubicTo(
        size.width * 0.18,
        size.height * 0.78,
        0,
        size.height * 0.56,
        0,
        size.width / 2,
      )
      ..arcToPoint(
        Offset(size.width, size.width / 2),
        radius: Radius.circular(size.width / 2),
        clockwise: true,
      )
      ..cubicTo(
        size.width,
        size.height * 0.56,
        size.width * 0.82,
        size.height * 0.78,
        size.width / 2,
        size.height,
      )
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MapPinPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

// ─── EXAMPLE USAGE ─────────────────────────────────────────────────────────

class CustomMapPinExampleView extends StatelessWidget {
  const CustomMapPinExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom Map Pin'),
      ),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(16),
          ),
          // Demonstrating the widget usage
          child: const CustomMapPin(),
        ),
      ),
    );
  }
}
