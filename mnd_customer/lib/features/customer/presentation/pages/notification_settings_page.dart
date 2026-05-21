import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/features/customer/domain/entities/notification_settings.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/notification_settings_provider.dart';

class NotificationSettingsPage extends ConsumerWidget {
  const NotificationSettingsPage({super.key});

  static Future<void> _setOrderUpdates(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    try {
      await ref.read(notificationSettingsProvider.notifier).setOrderUpdates(value);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update order notifications: $e')),
        );
      }
    }
  }

  static Future<void> _setPromotions(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    try {
      await ref.read(notificationSettingsProvider.notifier).setPromotions(value);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update promotions: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AppNotificationSettings> async =
        ref.watch(notificationSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: async.when(
        data: (AppNotificationSettings s) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(notificationSettingsProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: <Widget>[
                const _SystemPermissionCard(),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Notification types',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    children: <Widget>[
                      SwitchListTile.adaptive(
                        secondary: Icon(Icons.local_shipping_outlined, color: AppColors.primaryBlue),
                        title: const Text('Order updates'),
                        subtitle: const Text(
                          'Status changes, rider assigned, out for delivery.',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: s.orderUpdates,
                        onChanged: (bool v) => _setOrderUpdates(context, ref, v),
                      ),
                      const Divider(height: 1),
                      SwitchListTile.adaptive(
                        secondary: Icon(Icons.local_offer_outlined, color: AppColors.primaryBlue),
                        title: const Text('Offers & promotions'),
                        subtitle: const Text(
                          'Discounts and featured deals from shops.',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: s.promotions,
                        onChanged: (bool v) => _setPromotions(context, ref, v),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  'Could not load settings.\n$e',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  onPressed: () => ref.invalidate(notificationSettingsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SystemPermissionCard extends StatefulWidget {
  const _SystemPermissionCard();

  @override
  State<_SystemPermissionCard> createState() => _SystemPermissionCardState();
}

class _SystemPermissionCardState extends State<_SystemPermissionCard> {
  Future<NotificationSettings>? _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = FirebaseMessaging.instance.getNotificationSettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NotificationSettings>(
      future: _future,
      builder: (BuildContext context, AsyncSnapshot<NotificationSettings> snapshot) {
        final ThemeData theme = Theme.of(context);
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
            ),
            child: const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final NotificationSettings? sys = snapshot.data;
        final AuthorizationStatus? status = sys?.authorizationStatus;
        final bool granted = status == AuthorizationStatus.authorized ||
            status == AuthorizationStatus.provisional;
        final String label = switch (status) {
          AuthorizationStatus.authorized => 'Allowed',
          AuthorizationStatus.provisional => 'Provisional',
          AuthorizationStatus.denied => 'Blocked',
          AuthorizationStatus.notDetermined => 'Not asked yet',
          _ => 'Unknown',
        };

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      granted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
                      color: granted ? Colors.green.shade700 : theme.colorScheme.error,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'System access',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  granted
                      ? 'Notifications are enabled at the system level ($label).'
                      : status == AuthorizationStatus.denied
                          ? 'Notifications are off in system settings. Enable them to receive alerts.'
                          : 'Allow notifications when prompted, or enable them in your device settings.',
                  style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.black87,
                        height: 1.35,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton.icon(
                  onPressed: () async {
                    await FirebaseMessaging.instance.requestPermission(
                      alert: true,
                      badge: true,
                      sound: true,
                    );
                    _reload();
                  },
                  icon: const Icon(Icons.touch_app_rounded, size: 20),
                  label: Text(granted ? 'Refresh permission status' : 'Request permission'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
