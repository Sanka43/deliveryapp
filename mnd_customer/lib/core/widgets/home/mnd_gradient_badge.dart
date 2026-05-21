import 'package:flutter/material.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';

enum MndBadgeStyle { brand, success, offer, neutral }

class MndGradientBadge extends StatelessWidget {
  const MndGradientBadge({
    required this.label,
    this.style = MndBadgeStyle.brand,
    super.key,
  });

  final String label;
  final MndBadgeStyle style;

  @override
  Widget build(BuildContext context) {
    final ({List<Color> colors, Color text}) palette = switch (style) {
      MndBadgeStyle.brand => (
          colors: <Color>[AppColors.brandPrimary, AppColors.brandPrimaryLight],
          text: Colors.white,
        ),
      MndBadgeStyle.success => (
          colors: <Color>[AppColors.success, Color(0xFF22C55E)],
          text: Colors.white,
        ),
      MndBadgeStyle.offer => (
          colors: <Color>[AppColors.offerOrange, Color(0xFFFB923C)],
          text: Colors.white,
        ),
      MndBadgeStyle.neutral => (
          colors: <Color>[AppColors.homeMutedFill, AppColors.homeMutedFill],
          text: AppColors.textSecondary,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: palette.colors),
        borderRadius: BorderRadius.circular(999),
        boxShadow: style == MndBadgeStyle.neutral
            ? null
            : <BoxShadow>[
                BoxShadow(
                  color: palette.colors.first.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: palette.text,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
