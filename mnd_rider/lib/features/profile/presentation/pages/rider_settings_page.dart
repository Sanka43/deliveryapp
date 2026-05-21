import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_rider/app/providers/theme_mode_provider.dart';
import 'package:mnd_rider/core/constants/app_spacing.dart';
import 'package:mnd_rider/features/auth/presentation/providers/rider_approval_provider.dart';
import 'package:mnd_rider/features/dashboard/presentation/providers/rider_dashboard_provider.dart';
import 'package:mnd_rider/features/profile/domain/rider_notification_settings.dart';
import 'package:mnd_rider/features/profile/presentation/providers/rider_notification_settings_provider.dart';
import 'package:mnd_rider/features/profile/presentation/widgets/rider_settings_tile.dart';

class RiderSettingsPage extends ConsumerWidget {
  const RiderSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isOnline = ref.watch(riderDashboardProvider).isOnline;
    final bool canGoOnline = ref.watch(riderIsApprovedToDriveProvider);
    final AsyncValue<RiderNotificationSettings> notifications =
        ref.watch(riderNotificationSettingsProvider);
    final ThemeMode themeMode =
        ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.light;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.screenPadding,
          8,
          AppSpacing.screenPadding,
          32 + MediaQuery.paddingOf(context).bottom,
        ),
        children: <Widget>[
          const RiderSettingsSectionHeader(title: 'Availability'),
          RiderSettingsTile(
            icon: Icons.wifi_tethering_rounded,
            title: 'Online for deliveries',
            subtitle: canGoOnline
                ? (isOnline ? 'You are visible for new jobs' : 'You are offline')
                : 'Available after admin approval',
            trailing: Switch.adaptive(
              value: isOnline,
              onChanged: canGoOnline
                  ? (bool v) async {
                      final String? err = await ref
                          .read(riderDashboardProvider.notifier)
                          .setOnline(v);
                      if (context.mounted && err != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(err)),
                        );
                      }
                    }
                  : null,
            ),
          ),
          const RiderSettingsSectionHeader(title: 'Notifications'),
          notifications.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (Object e, _) => Text('Could not load: $e'),
            data: (RiderNotificationSettings n) => Column(
              children: <Widget>[
                RiderSettingsTile(
                  icon: Icons.delivery_dining_outlined,
                  title: 'New delivery offers',
                  trailing: Switch.adaptive(
                    value: n.orderOffersEnabled,
                    onChanged: (bool v) => ref
                        .read(riderNotificationSettingsProvider.notifier)
                        .setOrderOffers(v),
                  ),
                ),
                RiderSettingsTile(
                  icon: Icons.route_outlined,
                  title: 'Delivery updates',
                  trailing: Switch.adaptive(
                    value: n.deliveryUpdatesEnabled,
                    onChanged: (bool v) => ref
                        .read(riderNotificationSettingsProvider.notifier)
                        .setDeliveryUpdates(v),
                  ),
                ),
                RiderSettingsTile(
                  icon: Icons.payments_outlined,
                  title: 'Earnings alerts',
                  trailing: Switch.adaptive(
                    value: n.earningsAlertsEnabled,
                    onChanged: (bool v) => ref
                        .read(riderNotificationSettingsProvider.notifier)
                        .setEarningsAlerts(v),
                  ),
                ),
                RiderSettingsTile(
                  icon: Icons.campaign_outlined,
                  title: 'Promotions & tips',
                  trailing: Switch.adaptive(
                    value: n.promotionsEnabled,
                    onChanged: (bool v) => ref
                        .read(riderNotificationSettingsProvider.notifier)
                        .setPromotions(v),
                  ),
                ),
              ],
            ),
          ),
          const RiderSettingsSectionHeader(title: 'Appearance'),
          RiderSettingsTile(
            icon: themeMode == ThemeMode.dark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined,
            title: 'Dark mode',
            subtitle: themeMode == ThemeMode.dark ? 'On' : 'Off',
            trailing: Switch.adaptive(
              value: themeMode == ThemeMode.dark,
              onChanged: (_) =>
                  ref.read(themeModeProvider.notifier).toggle(),
            ),
          ),
        ],
      ),
    );
  }
}
