import 'package:flutter/material.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';

/// Visual indicator that the current user was booked for a job.
class JobBookedBadge extends StatelessWidget {
  const JobBookedBadge({
    this.compact = false,
    this.showLabel = true,
    super.key,
  });

  /// Icon-only badge for job cards and app bars.
  const JobBookedBadge.compact({super.key})
      : compact = true,
        showLabel = false;

  final bool compact;
  final bool showLabel;

  static const IconData bookedIcon = Icons.event_available_rounded;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    if (compact) {
      return Tooltip(
        message: 'Booked',
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.success.withValues(alpha: 0.35),
            ),
          ),
          child: const Icon(
            bookedIcon,
            size: 16,
            color: AppColors.success,
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: showLabel ? 10 : 8,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(bookedIcon, size: 18, color: AppColors.success),
          if (showLabel) ...<Widget>[
            const SizedBox(width: 6),
            Text(
              'Booked',
              style: textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.success,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Full-width success banner on job detail when the user is booked.
class JobBookedBanner extends StatelessWidget {
  const JobBookedBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppColors.cardRadiusMd),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              JobBookedBadge.bookedIcon,
              color: AppColors.success,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'You are booked',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'The employer selected you for this job. Contact them to confirm start date.',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
