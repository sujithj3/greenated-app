import 'package:flutter/material.dart';
import 'app_colors.dart';

extension SnackBarHelper on BuildContext {
  void showSnack(String msg, {bool success = false}) {
    final messenger = ScaffoldMessenger.of(this);
    messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? AppColors.primary : AppColors.error,
      behavior: SnackBarBehavior.floating,
    ));
  }
}
