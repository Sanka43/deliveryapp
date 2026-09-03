import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/core/constants/app_colors.dart';
import 'package:mnd_shop/core/utils/user_facing_error.dart';
import 'package:mnd_shop/features/notifications/data/vendor_notifications_repository.dart';
import 'package:mnd_shop/features/notifications/domain/vendor_notification.dart';
import 'package:mnd_shop/features/notifications/presentation/providers/vendor_notifications_providers.dart';
import 'package:mnd_shop/features/products/presentation/providers/vendor_session_store_providers.dart';

/// Lists Firestore notifications for `vendors/{storeId}/notifications`.
class VendorNotificationsPage extends ConsumerWidget {
  const VendorNotificationsPage({super.key});

  static String _formatTime(DateTime? d) {
    if (d == null) {
      return '';
    }
    final String mm = d.minute.toString().padLeft(2, '0');
    return '${d.day}/${d.month}/${d.year} · ${d.hour}:$mm';
  }

  static IconData _iconForType(String type) {
    switch (type) {
      case VendorNotification.kTypeOrderNew:
      case VendorNotification.kTypeOrderReminder:
        return Icons.receipt_long_rounded;
      case VendorNotification.kTypeOrderCancelled:
        return Icons.cancel_outlined;
      case VendorNotification.kTypeApproval:
        return Icons.verified_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final String storeId = ref.watch(vendorEffectiveStoreIdProvider).trim();
    final AsyncValue<List<VendorNotification>> list = ref.watch(vendorNotificationsListProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: <Widget>[
          if (storeId.isNotEmpty)
            TextButton(
              onPressed: () async {
                final String? err =
                    await ref.read(vendorNotificationsRepositoryProvider).markAllRead(storeId);
                if (!context.mounted) {
                  return;
                }
                if (err != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(err), backgroundColor: cs.error),
                  );
                }
              },
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: storeId.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Link your store under Products to load notifications.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
                ),
              ),
            )
          : list.when(
              loading: () => const Center(child: CircularProgressIndicator.adaptive()),
              error: (Object e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Could not load notifications.\n${userFacingError(e, fallback: 'Please check your connection and try again.')}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: cs.error),
                  ),
                ),
              ),
              data: (List<VendorNotification> items) {
                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(
                            Icons.notifications_none_rounded,
                            size: 56,
                            color: cs.primary.withValues(alpha: 0.35),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No notifications yet',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Order alerts and updates will appear here.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  color: cs.primary,
                  onRefresh: () async {
                    ref.invalidate(vendorNotificationsListProvider);
                    ref.invalidate(vendorUnreadNotificationCountProvider);
                    await Future<void>.delayed(const Duration(milliseconds: 400));
                  },
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    itemCount: items.length,
                    separatorBuilder: (BuildContext context, int index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (BuildContext context, int i) {
                      final VendorNotification n = items[i];
                      return _NotificationTile(
                        notification: n,
                        timeLabel: _formatTime(n.createdAt),
                        icon: _iconForType(n.type),
                        onTap: () async {
                          if (!n.read) {
                            final String? err = await ref
                                .read(vendorNotificationsRepositoryProvider)
                                .markRead(vendorId: storeId, notificationId: n.id);
                            if (!context.mounted) {
                              return;
                            }
                            if (err != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(err), backgroundColor: cs.error),
                              );
                            }
                          }
                        },
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.timeLabel,
    required this.icon,
    required this.onTap,
  });

  final VendorNotification notification;
  final String timeLabel;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final bool unread = !notification.read;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: unread ? cs.primary.withValues(alpha: 0.06) : cs.surface.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: unread
                  ? cs.primary.withValues(alpha: 0.22)
                  : cs.outlineVariant.withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: cs.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            notification.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                            ),
                          ),
                        ),
                        if (unread)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: cs.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    if (notification.body.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        notification.body,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textMuted,
                          height: 1.35,
                        ),
                      ),
                    ],
                    if (timeLabel.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        timeLabel,
                        style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
