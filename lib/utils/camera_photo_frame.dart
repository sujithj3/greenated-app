import 'package:flutter/widgets.dart';

class CameraPhotoFrame {
  static const double portraitAspectRatio = 3 / 4;
  static const double landscapeAspectRatio = 4 / 3;

  static double aspectRatioForOrientation(Orientation orientation) {
    return orientation == Orientation.landscape
        ? landscapeAspectRatio
        : portraitAspectRatio;
  }

  static double aspectRatioForImageSize({
    required int width,
    required int height,
  }) {
    return width >= height ? landscapeAspectRatio : portraitAspectRatio;
  }
}
