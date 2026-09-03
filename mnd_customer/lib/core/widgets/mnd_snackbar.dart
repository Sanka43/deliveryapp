import 'package:flutter/material.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';

enum MndSnackBarVariant { info, success, error, warning }

/// Premium floating alerts shown from the bottom of the screen.
class MndSnackBar {
  MndSnackBar._();

  static const Duration defaultDuration = Duration(seconds: 3);

  static void show(
    BuildContext context, {
    required String message,
    MndSnackBarVariant variant = MndSnackBarVariant.info,
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
        variant: variant,
        actionLabel: actionLabel,
        onAction: onAction,
        duration: duration,
      ),
    );
  }

  static void clear(BuildContext context) {
    ScaffoldMessenger.of(context).clearSnackBars();
  }

  static void showSuccess(BuildContext context, String message) {
    show(context, message: message, variant: MndSnackBarVariant.success);
  }

  static void showError(BuildContext context, String message) {
    show(context, message: message, variant: MndSnackBarVariant.error);
  }

  static void showInfo(BuildContext context, String message) {
    show(context, message: message, variant: MndSnackBarVariant.info);
  }

  static void showWarning(BuildContext context, String message) {
    show(context, message: message, variant: MndSnackBarVariant.warning);
  }

  static SnackBar build(
    BuildContext context, {
    required String message,
    MndSnackBarVariant variant = MndSnackBarVariant.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = defaultDuration,
  }) {
    final _VariantStyle style = _styleFor(variant);
    final double bottomInset = MediaQuery.paddingOf(context).bottom;

    return SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
      padding: EdgeInsets.zero,
      duration: duration,
      dismissDirection: DismissDirection.down,
      content: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(AppColors.cardRadiusMd),
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
            boxShadow: AppColors.shadowElevated,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: style.iconBackground,
                  borderRadius: BorderRadius.circular(AppColors.cardRadiusSm),
                ),
                child: Icon(style.icon, size: 18, color: style.iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (actionLabel != null && onAction != null) ...<Widget>[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    onAction();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.brandPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    actionLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static _VariantStyle _styleFor(MndSnackBarVariant variant) {
    return switch (variant) {
      MndSnackBarVariant.success => const _VariantStyle(
          icon: Icons.check_circle_rounded,
          iconColor: AppColors.success,
          iconBackground: Color(0x1A16A34A),
        ),
      MndSnackBarVariant.error => const _VariantStyle(
          icon: Icons.error_outline_rounded,
          iconColor: AppColors.error,
          iconBackground: Color(0x1ADC2626),
        ),
      MndSnackBarVariant.warning => const _VariantStyle(
          icon: Icons.warning_amber_rounded,
          iconColor: AppColors.warning,
          iconBackground: Color(0x1AF59E0B),
        ),
      MndSnackBarVariant.info => const _VariantStyle(
          icon: Icons.info_outline_rounded,
          iconColor: AppColors.brandPrimary,
          iconBackground: Color(0x1A0B6EFF),
        ),
    };
  }
}

class _VariantStyle {
  const _VariantStyle({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
}

/// Shorthand for [MndSnackBar.show].
void showMndSnackBar(
  BuildContext context,
  String message, {
  MndSnackBarVariant variant = MndSnackBarVariant.info,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = MndSnackBar.defaultDuration,
}) {
  MndSnackBar.show(
    context,
    message: message,
    variant: variant,
    actionLabel: actionLabel,
    onAction: onAction,
    duration: duration,
  );
}
