import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_rider/app/providers/theme_mode_provider.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/core/constants/app_spacing.dart';
import 'package:mnd_rider/core/constants/route_paths.dart';
import 'package:mnd_rider/core/utils/user_facing_error.dart';
import 'package:mnd_rider/core/widgets/rider_branded_dialog.dart';
import 'package:mnd_rider/core/widgets/rider_error_state.dart';
import 'package:mnd_rider/core/widgets/rider_loading_scaffold.dart';
import 'package:mnd_rider/core/widgets/rider_snackbar.dart';
import 'package:mnd_rider/features/auth/data/rider_session_actions.dart';
import 'package:mnd_rider/features/auth/presentation/providers/rider_approval_provider.dart';
import 'package:mnd_rider/features/dashboard/presentation/providers/rider_dashboard_provider.dart';
import 'package:mnd_rider/features/notifications/data/rider_notifications_repository.dart';
import 'package:mnd_rider/features/profile/data/rider_profile_repository.dart';
import 'package:mnd_rider/features/profile/domain/rider_compliance_doc.dart';
import 'package:mnd_rider/features/profile/domain/rider_profile.dart';
import 'package:mnd_rider/features/profile/presentation/widgets/rider_profile_header_card.dart';
import 'package:mnd_rider/features/profile/presentation/widgets/rider_settings_tile.dart';
import 'package:mnd_rider/features/shell/presentation/widgets/rider_floating_nav_bar.dart';

class RiderProfilePage extends ConsumerWidget {
  const RiderProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<RiderProfile?> profileAsync =
        ref.watch(riderProfileStreamProvider);
    final bool isOnline = ref.watch(riderDashboardProvider).isOnline;
    final bool canGoOnline = ref.watch(riderIsApprovedToDriveProvider);
    final ThemeMode themeMode =
        ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.light;

    ref.listen<AsyncValue<RiderProfile?>>(riderProfileStreamProvider, (
      AsyncValue<RiderProfile?>? _,
      AsyncValue<RiderProfile?> next,
    ) {
      final bool? online = next.valueOrNull?.isOnline;
      if (online != null) {
        ref.read(riderDashboardProvider.notifier).syncOnlineFromRemote(online);
      }
    });

    if (profileAsync.isLoading && !profileAsync.hasValue) {
      return const RiderLoadingScaffold(message: 'Loading profile…');
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(
          child: RiderErrorState(
            message: userFacingError(
              e,
              fallback: 'Could not load profile. Please try again.',
            ),
            onRetry: () => ref.invalidate(riderProfileStreamProvider),
          ),
        ),
        data: (RiderProfile? p) {
          final RiderProfile profile = p ?? const RiderProfile.guest();
          final int unread =
              ref.watch(riderUnreadNotificationCountProvider).valueOrNull ?? 0;

          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[
              SliverAppBar(
                pinned: true,
                automaticallyImplyLeading: false,
                title: const Text('Profile'),
                centerTitle: false,
                actions: <Widget>[
                  IconButton(
                    tooltip: 'Edit profile',
                    onPressed: () => context.push(
                      RoutePaths.profileEdit,
                      extra: profile,
                    ),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  4,
                  AppSpacing.screenPadding,
                  16 + riderFloatingNavTotalHeight(context),
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    <Widget>[
                      RiderProfileHeaderCard(profile: profile),
                      const SizedBox(height: 18),
                      _AvailabilityCard(
                        isOnline: isOnline,
                        canGoOnline: canGoOnline,
                        onChanged: canGoOnline
                            ? (bool v) async {
                                final String? err = await ref
                                    .read(riderDashboardProvider.notifier)
                                    .setOnline(v);
                                if (context.mounted && err != null) {
                                  showRiderSnackBar(context, err);
                                }
                              }
                            : null,
                      ),
                      const RiderSettingsSectionHeader(title: 'Account'),
                      RiderProfileMenuGroup(
                        children: <Widget>[
                          RiderProfileMenuRow(
                            icon: Icons.notifications_outlined,
                            title: 'Notifications',
                            subtitle: unread > 0
                                ? '$unread unread'
                                : 'Inbox and alerts',
                            onTap: () =>
                                context.push(RoutePaths.notifications),
                          ),
                          RiderProfileMenuRow(
                            icon: Icons.badge_outlined,
                            title: 'License & vehicle',
                            subtitle:
                                '${profile.vehicleType.label} · ${profile.vehicleNumber}',
                            onTap: () => context.push(
                              RoutePaths.profileEdit,
                              extra: profile,
                            ),
                          ),
                          RiderProfileMenuRow(
                            icon: Icons.description_outlined,
                            title: 'Documents',
                            subtitle: _documentsSubtitle(profile),
                            onTap: () =>
                                context.push(RoutePaths.renewDocuments),
                          ),
                          RiderProfileMenuRow(
                            icon: Icons.history_rounded,
                            title: 'Delivery history',
                            subtitle: 'Past trips and deliveries',
                            onTap: () => context.push(RoutePaths.history),
                          ),
                          RiderProfileMenuRow(
                            icon: Icons.receipt_long_outlined,
                            title: 'Transactions',
                            subtitle: 'Payouts and wallet history',
                            onTap: () =>
                                context.push(RoutePaths.transactions),
                          ),
                          RiderProfileMenuRow(
                            icon: Icons.summarize_outlined,
                            title: 'Reports',
                            subtitle: 'Export a PDF earnings & cash report',
                            onTap: () => context.push(RoutePaths.report),
                          ),
                        ],
                      ),
                      const RiderSettingsSectionHeader(title: 'Preferences'),
                      RiderProfileMenuGroup(
                        children: <Widget>[
                          RiderProfileMenuRow(
                            icon: Icons.tune_rounded,
                            title: 'Settings',
                            subtitle: 'Notifications and app prefs',
                            onTap: () => context.push(RoutePaths.settings),
                          ),
                          RiderProfileMenuRow(
                            icon: themeMode == ThemeMode.dark
                                ? Icons.dark_mode_outlined
                                : Icons.light_mode_outlined,
                            title: 'Dark mode',
                            subtitle:
                                themeMode == ThemeMode.dark ? 'On' : 'Off',
                            trailing: Switch.adaptive(
                              value: themeMode == ThemeMode.dark,
                              onChanged: (_) => ref
                                  .read(themeModeProvider.notifier)
                                  .toggle(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _SignOutButton(
                        onPressed: () async {
                          final bool confirm = await showRiderConfirmDialog(
                            context,
                            title: 'Sign out?',
                            message:
                                'You will go offline and need to sign in again.',
                            confirmLabel: 'Sign out',
                            isDestructive: true,
                          );
                          if (confirm) {
                            await riderSignOutAndClear(ref);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// "All valid" or a note about the soonest-expiring/expired document.
String _documentsSubtitle(RiderProfile profile) {
  final List<RiderComplianceDocStatus> statuses = riderComplianceDocStatuses(
    licenseExpiresAt: profile.licenseExpiresAt,
    insuranceExpiresAt: profile.insuranceExpiresAt,
    revenueLicenseExpiresAt: profile.revenueLicenseExpiresAt,
  );
  final int expiredCount = statuses.where((s) => s.isExpired).length;
  if (expiredCount > 0) {
    return '$expiredCount document${expiredCount == 1 ? '' : 's'} expired';
  }
  final List<RiderComplianceDocStatus> expiringSoon =
      statuses.where((s) => s.isExpiringSoon).toList()
        ..sort(
          (a, b) => a.daysUntilExpiry!.compareTo(b.daysUntilExpiry!),
        );
  if (expiringSoon.isNotEmpty) {
    return '${expiringSoon.first.kind.label} expires in ${expiringSoon.first.daysUntilExpiry}d';
  }
  return 'All valid';
}

class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.error,
          backgroundColor: cs.error.withValues(alpha: 0.04),
          side: BorderSide(color: cs.error.withValues(alpha: 0.35)),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
          textStyle: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.logout_rounded, size: 18),
            SizedBox(width: 8),
            Text('Sign out'),
          ],
        ),
      ),
    );
  }
}

class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard({
    required this.isOnline,
    required this.canGoOnline,
    required this.onChanged,
  });

  final bool isOnline;
  final bool canGoOnline;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Color accent =
        isOnline ? AppColors.onlineGreen : AppColors.offlineGrey;
    final bool enabled = onChanged != null;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1 : 0.72,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? () => onChanged!(!isOnline) : null,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              border: Border.all(
                color: isOnline
                    ? accent.withValues(alpha: 0.35)
                    : cs.outlineVariant,
              ),
            ),
            child: Row(
              children: <Widget>[
                _StatusMark(online: isOnline, accent: accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        isOnline ? 'Online' : 'Offline',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        !canGoOnline
                            ? 'Available after admin approval'
                            : isOnline
                                ? 'Accepting new job offers'
                                : 'Go online to receive jobs',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Switch.adaptive(
                  value: isOnline,
                  activeTrackColor: AppColors.onlineGreen,
                  activeThumbColor: Colors.white,
                  onChanged: onChanged,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusMark extends StatelessWidget {
  const _StatusMark({required this.online, required this.accent});

  final bool online;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: online
            ? accent.withValues(alpha: 0.12)
            : cs.surfaceContainerLow,
        shape: BoxShape.circle,
        border: Border.all(
          color: online
              ? accent.withValues(alpha: 0.28)
              : cs.outlineVariant.withValues(alpha: 0.8),
        ),
      ),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          width: online ? 10 : 8,
          height: online ? 10 : 8,
          decoration: BoxDecoration(
            color: accent,
            shape: BoxShape.circle,
            boxShadow: online
                ? <BoxShadow>[
                    BoxShadow(
                      color: accent.withValues(alpha: 0.35),
                      blurRadius: 6,
                      spreadRadius: 0.5,
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }
}
