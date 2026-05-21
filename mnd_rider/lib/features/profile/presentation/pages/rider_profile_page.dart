import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_rider/app/providers/theme_mode_provider.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/core/constants/app_spacing.dart';
import 'package:mnd_rider/core/constants/route_paths.dart';
import 'package:mnd_rider/core/widgets/rider_large_card.dart';
import 'package:mnd_rider/features/auth/data/rider_session_actions.dart';
import 'package:mnd_rider/features/auth/presentation/providers/rider_approval_provider.dart';
import 'package:mnd_rider/features/dashboard/presentation/providers/rider_dashboard_provider.dart';
import 'package:mnd_rider/features/profile/data/rider_avatar_storage.dart';
import 'package:mnd_rider/features/profile/data/rider_profile_repository.dart';
import 'package:mnd_rider/features/profile/domain/rider_profile.dart';
import 'package:mnd_rider/features/profile/presentation/widgets/rider_profile_header_card.dart';
import 'package:mnd_rider/features/profile/presentation/widgets/rider_settings_tile.dart';

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

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkCanvas
          : AppColors.canvas,
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(child: Text('Could not load profile: $e')),
        data: (RiderProfile? p) {
          final RiderProfile profile = p ?? const RiderProfile.guest();

          return CustomScrollView(
            slivers: <Widget>[
              SliverAppBar(
                pinned: true,
                title: const Text('Profile'),
                actions: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    tooltip: 'Settings',
                    onPressed: () => context.push(RoutePaths.settings),
                  ),
                ],
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  8,
                  AppSpacing.screenPadding,
                  32 + MediaQuery.paddingOf(context).bottom + 72,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    <Widget>[
                      RiderProfileHeaderCard(
                        profile: profile,
                        onChangePhoto: () async {
                          final String? err = await ref
                              .read(riderAvatarStorageProvider)
                              .pickAndUploadProfile();
                          if (context.mounted && err != null && err.isNotEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(err)),
                            );
                          }
                        },
                        onEditProfile: () => context.push(
                          RoutePaths.profileEdit,
                          extra: profile,
                        ),
                      ),
                      const SizedBox(height: 16),
                      RiderLargeCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              Icons.wifi_tethering_rounded,
                              color: isOnline
                                  ? AppColors.onlineGreen
                                  : AppColors.offlineGrey,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    isOnline ? 'You are online' : 'You are offline',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  Text(
                                    canGoOnline
                                        ? 'Toggle availability for new jobs'
                                        : 'Go online after admin approval',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: isOnline,
                              onChanged: canGoOnline
                                  ? (bool v) async {
                                      final String? err = await ref
                                          .read(riderDashboardProvider.notifier)
                                          .setOnline(v);
                                      if (context.mounted && err != null) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(content: Text(err)));
                                      }
                                    }
                                  : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const RiderSettingsSectionHeader(title: 'Account'),
                      RiderSettingsTile(
                        icon: Icons.badge_outlined,
                        title: 'License & vehicle',
                        subtitle:
                            '${profile.vehicleType.label} · ${profile.vehicleNumber}',
                        onTap: () => context.push(
                          RoutePaths.profileEdit,
                          extra: profile,
                        ),
                      ),
                      RiderSettingsTile(
                        icon: Icons.history_rounded,
                        title: 'Delivery history',
                        onTap: () => context.push(RoutePaths.history),
                      ),
                      const RiderSettingsSectionHeader(title: 'Preferences'),
                      RiderSettingsTile(
                        icon: Icons.tune_rounded,
                        title: 'Settings',
                        subtitle: 'Notifications, appearance',
                        onTap: () => context.push(RoutePaths.settings),
                      ),
                      RiderSettingsTile(
                        icon: themeMode == ThemeMode.dark
                            ? Icons.dark_mode_outlined
                            : Icons.light_mode_outlined,
                        title: 'Dark mode',
                        subtitle: themeMode == ThemeMode.dark ? 'On' : 'Off',
                        trailing: Switch.adaptive(
                          value: themeMode == ThemeMode.dark,
                          onChanged: (_) =>
                              ref.read(themeModeProvider.notifier).toggle(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      RiderSettingsTile(
                        icon: Icons.logout_rounded,
                        title: 'Sign out',
                        destructive: true,
                        onTap: () async {
                          final bool? confirm = await showDialog<bool>(
                            context: context,
                            builder: (BuildContext ctx) => AlertDialog(
                              title: const Text('Sign out?'),
                              content: const Text(
                                'You will go offline and need to sign in again.',
                              ),
                              actions: <Widget>[
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Sign out'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
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
