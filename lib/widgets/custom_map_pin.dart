import 'package:flutter/material.dart';

/// A modern, reusable custom map pin marker widget.
/// 
/// It draws a teardrop/pin shape programmatically using [CustomPainter] 
/// with smooth Bezier curves and places an icon inside the top circular area.
class CustomMapPin extends StatelessWidget {
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
    this.pinColor = Colors.red,
    this.iconAsset = 'assets/images/four-way-arrow.png',
    this.iconSize = 28,
    this.isUpsideDown = false,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate the visual center of the top circle
    final double circleCenterY = isUpsideDown ? height - (width / 2) : width / 2;
    
    // Shift slightly towards the circle center for better visual balance
    final double visualCenterY = isUpsideDown ? circleCenterY + 4 : circleCenterY - 4;

    Widget paintWidget = CustomPaint(
      size: Size(width, height),
      painter: _MapPinPainter(
        color: pinColor.withValues(alpha: 0.6),
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
          
          // The icon, positioned inside the circle
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

    final path = Path();
    
    // Start at the bottom pointed tip
    path.moveTo(size.width / 2, size.height);
    
    // Left smooth curve from bottom tip to the left edge of the top circle
    path.quadraticBezierTo(
      0, 
      size.height * 0.7, 
      0, 
      size.width / 2,
    );
    
    // Top semi-circle
    path.arcToPoint(
      Offset(size.width, size.width / 2),
      radius: Radius.circular(size.width / 2),
      clockwise: true,
    );
    
    // Right smooth curve from the right edge back down to the bottom tip
    path.quadraticBezierTo(
      size.width, 
      size.height * 0.7, 
      size.width / 2, 
      size.height,
    );

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
