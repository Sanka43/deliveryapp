import 'package:flutter/material.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';

enum RiderStatusPillTone {
  online,
  offline,
  warning,
  arriving,
  delivering,
  info,
}

/// High-contrast status pill for driving chrome.
class RiderStatusPill extends StatelessWidget {
  const RiderStatusPill({
    super.key,
    required this.label,
    this.tone = RiderStatusPillTone.info,
    this.icon,
    this.compact = false,
  });

  final String label;
  final RiderStatusPillTone tone;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ({Color bg, Color fg}) colors = switch (tone) {
      RiderStatusPillTone.online => (
          bg: AppColors.onlineGreen,
          fg: Colors.white,
        ),
      RiderStatusPillTone.offline => (
          bg: AppColors.offlineGrey.withValues(alpha: 0.9),
          fg: Colors.white,
        ),
      RiderStatusPillTone.warning => (
          bg: AppColors.warningAmber,
          fg: AppColors.textCharcoal,
        ),
      RiderStatusPillTone.arriving => (
          bg: AppColors.pickupGreen,
          fg: Colors.white,
        ),
      RiderStatusPillTone.delivering => (
          bg: AppColors.dropoffRed,
          fg: Colors.white,
        ),
      RiderStatusPillTone.info => (
          bg: AppColors.accentBlue,
          fg: Colors.white,
        ),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 5 : 8,
      ),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(99),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colors.bg.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: compact ? 14 : 16, color: colors.fg),
            SizedBox(width: compact ? 4 : 6),
          ],
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.fg,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                  fontSize: compact ? 10 : 11,
                ),
          ),
        ],
      ),
    );
  }
}
