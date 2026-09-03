import 'package:flutter/material.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/core/constants/app_spacing.dart';

class RiderOnlineToggleCard extends StatelessWidget {
  const RiderOnlineToggleCard({
    super.key,
    required this.isOnline,
    required this.onChanged,
  });

  final bool isOnline;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: isOnline
            ? AppColors.onlineGreen.withValues(alpha: 0.12)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(
          color: isOnline ? AppColors.onlineGreen : theme.colorScheme.outlineVariant,
          width: 1.5,
        ),
      ),
      child: SwitchListTile(
        title: Text(
          isOnline ? 'You\'re online' : 'You\'re offline',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          isOnline ? 'Ready for delivery offers' : 'Go online to receive jobs',
        ),
        value: isOnline,
        activeThumbColor: AppColors.onlineGreen,
        onChanged: onChanged,
      ),
    );
  }
}
