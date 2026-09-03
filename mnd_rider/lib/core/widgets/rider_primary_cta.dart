import 'package:flutter/material.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/core/constants/app_spacing.dart';

/// Large filled CTA for driving actions (accept, phase advance, go online).
class RiderPrimaryCta extends StatelessWidget {
  const RiderPrimaryCta({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.color = AppColors.onlineGreen,
    this.foregroundColor = Colors.white,
    this.height = AppSpacing.ctaHeightLg,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final Color color;
  final Color foregroundColor;
  final double height;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final Widget child = busy
        ? SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: foregroundColor,
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 22, color: foregroundColor),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: foregroundColor,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                ),
              ),
            ],
          );

    final ButtonStyle style = FilledButton.styleFrom(
      backgroundColor: color,
      foregroundColor: foregroundColor,
      disabledBackgroundColor: color.withValues(alpha: 0.45),
      disabledForegroundColor: foregroundColor.withValues(alpha: 0.8),
      elevation: 0,
      minimumSize: Size(expanded ? double.infinity : 0, height),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
      ),
    );

    return FilledButton(
      onPressed: busy ? null : onPressed,
      style: style,
      child: child,
    );
  }
}

/// Secondary / reject CTA — outline on navy or light surfaces.
class RiderDangerCta extends StatelessWidget {
  const RiderDangerCta({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.height = AppSpacing.ctaHeight,
    this.onNavy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final double height;
  final bool onNavy;

  @override
  Widget build(BuildContext context) {
    // [onNavy] kept for call-site compatibility; sheets are light now.
    final Color border = AppColors.errorRed.withValues(alpha: 0.55);
    final Color fg = AppColors.errorRed;

    return OutlinedButton(
      onPressed: busy ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: fg,
        side: BorderSide(color: border, width: 1.5),
        minimumSize: Size(double.infinity, height),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        ),
      ),
      child: busy
          ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: fg),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(icon, size: 20, color: fg),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
    );
  }
}
