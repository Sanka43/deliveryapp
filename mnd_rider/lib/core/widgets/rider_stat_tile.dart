import 'package:flutter/material.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/core/constants/app_spacing.dart';

class RiderStatTile extends StatelessWidget {
  const RiderStatTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.accent,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Color highlight = accent ?? AppColors.primaryBlue;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: highlight.withValues(alpha: theme.brightness == Brightness.dark ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(AppSpacing.statRadius),
        border: Border.all(color: highlight.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 20, color: highlight),
              const SizedBox(height: 8),
            ],
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: highlight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
