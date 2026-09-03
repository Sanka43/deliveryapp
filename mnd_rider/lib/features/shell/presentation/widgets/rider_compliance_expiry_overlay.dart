import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/core/constants/route_paths.dart';
import 'package:mnd_rider/features/profile/data/rider_profile_repository.dart';
import 'package:mnd_rider/features/profile/domain/rider_compliance_doc.dart';
import 'package:mnd_rider/features/profile/domain/rider_profile.dart';

/// Resets to visible on every app cold start (in-memory only, per session).
final StateProvider<bool> _expiringSoonBannerDismissedProvider =
    StateProvider<bool>((Ref ref) => false);

/// App-wide banner for expiring/expired compliance documents — shown above
/// [child] on every tab/route under the shell, not just the dashboard.
class RiderComplianceExpiryOverlay extends ConsumerWidget {
  const RiderComplianceExpiryOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RiderProfile? profile =
        ref.watch(riderProfileStreamProvider).valueOrNull;

    Widget? banner;
    if (profile != null && profile.isApprovedToDrive) {
      final List<RiderComplianceDocStatus> statuses = riderComplianceDocStatuses(
        licenseExpiresAt: profile.licenseExpiresAt,
        insuranceExpiresAt: profile.insuranceExpiresAt,
        revenueLicenseExpiresAt: profile.revenueLicenseExpiresAt,
      );
      final bool anyExpired = statuses.any((s) => s.isExpired);
      final bool anyExpiringSoon = statuses.any((s) => s.isExpiringSoon);
      final bool dismissed = ref.watch(_expiringSoonBannerDismissedProvider);

      if (anyExpired) {
        banner = _ComplianceBanner(
          color: AppColors.errorRed,
          icon: Icons.error_outline_rounded,
          message: 'Documents expired — renew now to keep taking jobs.',
          onTap: () => context.push(RoutePaths.renewDocuments),
        );
      } else if (anyExpiringSoon && !dismissed) {
        final int count = statuses.where((s) => s.isExpiringSoon).length;
        banner = _ComplianceBanner(
          color: AppColors.warningAmber,
          icon: Icons.warning_amber_rounded,
          message:
              '$count document${count == 1 ? '' : 's'} expiring soon — renew to avoid interruption.',
          onTap: () => context.push(RoutePaths.renewDocuments),
          onDismiss: () =>
              ref.read(_expiringSoonBannerDismissedProvider.notifier).state = true,
        );
      }
    }

    return Column(
      children: <Widget>[
        if (banner != null) SafeArea(bottom: false, child: banner),
        Expanded(child: child),
      ],
    );
  }
}

class _ComplianceBanner extends StatelessWidget {
  const _ComplianceBanner({
    required this.color,
    required this.icon,
    required this.message,
    required this.onTap,
    this.onDismiss,
  });

  final Color color;
  final IconData icon;
  final String message;
  final VoidCallback onTap;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.14),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Renew',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                      decoration: TextDecoration.underline,
                    ),
              ),
              if (onDismiss != null) ...<Widget>[
                const SizedBox(width: 4),
                InkWell(
                  onTap: onDismiss,
                  child: Icon(Icons.close_rounded, size: 16, color: color),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
