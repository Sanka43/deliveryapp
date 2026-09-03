import 'package:flutter/material.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';

/// Floating snack bars pinned to the top of the screen.
class RiderSnackBar {
  RiderSnackBar._();

  static const Duration defaultDuration = Duration(seconds: 3);
  static const double _barHeightEstimate = 74;

  static void show(
    BuildContext context, {
    required String message,
    Color? backgroundColor,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = defaultDuration,
  }) {
    if (!context.mounted) {
      return;
    }
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      build(
        context,
        message: message,
        backgroundColor: backgroundColor,
        actionLabel: actionLabel,
        onAction: onAction,
        duration: duration,
      ),
    );
  }

  static void clear(BuildContext context) {
    ScaffoldMessenger.of(context).clearSnackBars();
  }

  static SnackBar build(
    BuildContext context, {
    required String message,
    Color? backgroundColor,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = defaultDuration,
  }) {
    final MediaQueryData mq = MediaQuery.of(context);
    final double topInset = mq.padding.top + 10;
    final double bottomMargin =
        (mq.size.height - topInset - _barHeightEstimate).clamp(72.0, double.infinity);
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color bg = backgroundColor ?? cs.inverseSurface;
    final Color onBg = cs.onInverseSurface;

    return SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: bg,
      elevation: 6,
      margin: EdgeInsets.fromLTRB(16, 0, 16, bottomMargin),
      duration: duration,
      dismissDirection: DismissDirection.up,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      action: actionLabel != null && onAction != null
          ? SnackBarAction(
              label: actionLabel,
              textColor: AppColors.brandSecondary,
              onPressed: onAction,
            )
          : null,
      content: Text(
        message,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.35,
          color: onBg,
        ),
      ),
    );
  }
}

/// Shorthand for [RiderSnackBar.show].
void showRiderSnackBar(
  BuildContext context,
  String message, {
  Color? backgroundColor,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = RiderSnackBar.defaultDuration,
}) {
  RiderSnackBar.show(
    context,
    message: message,
    backgroundColor: backgroundColor,
    actionLabel: actionLabel,
    onAction: onAction,
    duration: duration,
  );
}
