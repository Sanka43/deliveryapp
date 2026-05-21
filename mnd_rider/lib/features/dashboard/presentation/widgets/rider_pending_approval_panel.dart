import 'package:flutter/material.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/features/auth/domain/rider_profile_document.dart';

/// Shown on home when registration is complete but admin has not approved yet.
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
    final String name = profile?.fullName.isNotEmpty == true
        ? profile!.fullName
        : 'Rider';

    return Material(
      elevation: 16,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      color: cs.surface.withValues(alpha: 0.98),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          24 + MediaQuery.paddingOf(context).bottom + 72,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Icon(
              rejected ? Icons.block : Icons.hourglass_top_rounded,
              size: 52,
              color: rejected ? AppColors.errorRed : AppColors.warningAmber,
            ),
            const SizedBox(height: 16),
            Text(
              rejected ? 'Application not approved' : 'Waiting for admin approval',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              rejected
                  ? 'Your rider application was rejected. Contact MND support if you think this is a mistake.'
                  : 'Hi $name, your documents were submitted successfully. An admin will review your profile. You can go online and accept deliveries only after approval.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            DecoratedBox(
              decoration: BoxDecoration(
                color: (rejected ? AppColors.errorRed : AppColors.warningAmber)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: (rejected ? AppColors.errorRed : AppColors.warningAmber)
                      .withValues(alpha: 0.35),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: <Widget>[
                    Icon(
                      rejected ? Icons.info_outline : Icons.lock_outline,
                      color: rejected ? AppColors.errorRed : AppColors.warningAmber,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        rejected
                            ? 'Driving and job offers stay disabled.'
                            : 'Online mode and delivery offers are disabled until you are approved.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
