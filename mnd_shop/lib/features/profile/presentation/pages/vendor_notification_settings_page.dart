import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/app/providers/vendor_notification_prefs_provider.dart';
import 'package:mnd_shop/core/constants/app_colors.dart';
import 'package:permission_handler/permission_handler.dart';

class VendorNotificationSettingsPage extends ConsumerWidget {
  const VendorNotificationSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<VendorNotificationPrefs> prefsAsync =
        ref.watch(vendorNotificationPrefsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notification preferences')),
      body: prefsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(child: Text('Could not load settings.\n$e')),
        data: (VendorNotificationPrefs prefs) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: <Widget>[
              Card(
                child: ListTile(
                  leading: Icon(Icons.settings_outlined, color: AppColors.primaryBlue),
                  title: const Text('System notification settings'),
                  subtitle: const Text(
                    'Open your phone settings for app notifications.',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.open_in_new_rounded),
                  onTap: () => openAppSettings(),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'In this app',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 10),
              Card(
                child: Column(
                  children: <Widget>[
                    SwitchListTile.adaptive(
                      secondary: Icon(Icons.volume_up_rounded, color: AppColors.primaryBlue),
                      title: const Text('Order alert sound'),
                      subtitle: const Text(
                        'Play a sound when a new order arrives.',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: prefs.orderAlertSound,
                      onChanged: (bool v) async {
                        try {
                          await ref
                              .read(vendorNotificationPrefsProvider.notifier)
                              .setOrderAlertSound(v);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Could not save: $e')),
                            );
                          }
                        }
                      },
                    ),
                    const Divider(height: 1),
                    SwitchListTile.adaptive(
                      secondary: Icon(Icons.notifications_active_outlined,
                          color: AppColors.primaryBlue),
                      title: const Text('In-app order alerts'),
                      subtitle: const Text(
                        'Show a popup when a new order comes in.',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: prefs.inAppOrderAlerts,
                      onChanged: (bool v) async {
                        try {
                          await ref
                              .read(vendorNotificationPrefsProvider.notifier)
                              .setInAppOrderAlerts(v);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Could not save: $e')),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
