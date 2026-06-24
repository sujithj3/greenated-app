import 'package:flutter/material.dart';

import '../utils/app_colors.dart';

class CameraPreviewLoader extends StatefulWidget {
  final Color backgroundColor;

  const CameraPreviewLoader({
    super.key,
    this.backgroundColor = Colors.black,
  });

  @override
  State<CameraPreviewLoader> createState() => _CameraPreviewLoaderState();
}

class _CameraPreviewLoaderState extends State<CameraPreviewLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _opacity = Tween<double>(begin: 0.62, end: 1).animate(curved);
    _scale = Tween<double>(begin: 0.98, end: 1.03).animate(curved);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: widget.backgroundColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 18),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Opacity(
                    opacity: _opacity.value,
                    child: Transform.scale(
                      scale: _scale.value,
                      child: child,
                    ),
                  );
                },
                child: const Text(
                  'Preparing preview...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'This may take a moment on some devices.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
