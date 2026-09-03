import 'package:flutter/material.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/core/constants/app_spacing.dart';
import 'package:mnd_rider/features/auth/domain/rider_profile_document.dart';

/// Compact floating card when the rider is not yet approved to drive.
class RiderPendingApprovalPanel extends StatelessWidget {
  const RiderPendingApprovalPanel({
    super.key,
    required this.profile,
    this.rejected = false,
  });

  final RiderProfileDocument? profile;
  final bool rejected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Color accent =
        rejected ? AppColors.dropoffRed : AppColors.warningAmber;
    final String name = profile?.fullName.isNotEmpty == true
        ? profile!.fullName
        : 'Rider';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Material(
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
            border: Border.all(
              color: accent.withValues(alpha: 0.35),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    rejected ? Icons.block_rounded : Icons.hourglass_top_rounded,
                    color: accent,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  rejected
                      ? 'Application not approved'
                      : 'Waiting for admin approval',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  rejected
                      ? 'Contact MND support if you think this is a mistake.'
                      : 'Hi $name — you can go online after an admin approves your profile.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
