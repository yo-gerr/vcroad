import 'package:flutter/material.dart';

class SnackbarUtils {
  static void show(
    BuildContext context,
    String message, {
    Color? backgroundColor,
    IconData? icon,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    final theme = Theme.of(context);
    final color = backgroundColor ?? theme.colorScheme.primary;
    final iconWidget = icon != null
        ? Icon(icon, color: Colors.white, size: 20)
        : null;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (iconWidget != null) ...[iconWidget, const SizedBox(width: 8)],
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        action: action,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  static void showSuccess(BuildContext context, String message) {
    show(
      context,
      message,
      backgroundColor: Colors.green,
      icon: Icons.check_circle,
    );
  }

  static void showError(BuildContext context, String message) {
    show(
      context,
      message,
      backgroundColor: Colors.red,
      icon: Icons.error_outline,
    );
  }

  static void showInfo(BuildContext context, String message) {
    show(
      context,
      message,
      backgroundColor: Colors.blue,
      icon: Icons.info_outline,
    );
  }

  static void showWarning(BuildContext context, String message) {
    show(
      context,
      message,
      backgroundColor: Colors.orange,
      icon: Icons.warning_amber_rounded,
    );
  }
}
