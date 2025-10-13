import 'package:flutter/material.dart';

class SnackBarHelper {
  /// Shows a floating snackbar at the top of the screen
  static void showTopSnackBar(
    BuildContext context, {
    required String message,
    Color? backgroundColor,
    Color? textColor,
    IconData? icon,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    // Use Overlay to show at the very top
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 8, // Account for status bar
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: backgroundColor ?? Colors.grey[800],
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    color: textColor ?? Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      color: textColor ?? Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (action != null) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      overlayEntry.remove();
                      action.onPressed();
                    },
                    child: Text(
                      action.label,
                      style: TextStyle(
                        color: textColor ?? Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    
    overlay.insert(overlayEntry);
    
    // Auto remove after duration
    Future.delayed(duration, () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  /// Shows a success snackbar at the top
  static void showSuccess(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    showTopSnackBar(
      context,
      message: message,
      backgroundColor: Colors.green[600],
      icon: Icons.check_circle,
      duration: duration,
      action: action,
    );
  }

  /// Shows an error snackbar at the top
  static void showError(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    showTopSnackBar(
      context,
      message: message,
      backgroundColor: Colors.red[600],
      icon: Icons.error,
      duration: duration,
      action: action,
    );
  }

  /// Shows a warning snackbar at the top
  static void showWarning(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    showTopSnackBar(
      context,
      message: message,
      backgroundColor: Colors.orange[600],
      icon: Icons.warning,
      duration: duration,
      action: action,
    );
  }

  /// Shows an info snackbar at the top
  static void showInfo(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    showTopSnackBar(
      context,
      message: message,
      backgroundColor: Colors.blue[600],
      icon: Icons.info,
      duration: duration,
      action: action,
    );
  }

  /// Removes any currently displayed snackbar
  static void hide(BuildContext context) {
    // Note: With overlay approach, we can't easily track and remove specific overlays
    // The overlays will auto-remove after their duration
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
  }
}
