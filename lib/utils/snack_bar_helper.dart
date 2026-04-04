import 'package:flutter/material.dart';
import 'app_colors.dart';
import '../main.dart';

extension SnackBarHelper on BuildContext {
  /// Shows a floating SnackBar via the root [ScaffoldMessenger] so it renders
  /// above all routes, bottom sheets, and dialogs — never hidden behind them.
  void showSnack(String msg, {bool success = false}) {
    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? AppColors.primary : AppColors.error,
      behavior: SnackBarBehavior.floating,
    ));
  }
}
