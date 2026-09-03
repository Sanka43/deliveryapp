import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/utils/user_facing_error.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_page_app_bar.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_snackbar.dart';
import 'package:mnd_delivery_app/features/customer/data/customer_notifications_repository.dart';
import 'package:mnd_delivery_app/features/customer/domain/entities/customer_notification.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/customer_notifications_provider.dart';

/// Inbox of Firestore `notifications` for the signed-in customer.
class CustomerNotificationsPage extends ConsumerWidget {
  const CustomerNotificationsPage({super.key});

  static String _formatTime(DateTime? d) {
    if (d == null) {
      return '';
    }
    final String mm = d.minute.toString().padLeft(2, '0');
    return '${d.day}/${d.month}/${d.year} · ${d.hour}:$mm';
  }

  static IconData _iconForType(String type) {
    switch (type) {
      case 'payment':
        return Icons.payments_outlined;
      case 'rider_accepted':
        return Icons.delivery_dining_rounded;
      default:
        if (type.contains('order') || type.contains('status')) {
          return Icons.receipt_long_rounded;
        }
        if (type.contains('ride') || type.contains('trip')) {
          return Icons.directions_car_outlined;
        }
        return Icons.notifications_outlined;
    }
  }

  Future<void> _onTap(
    BuildContext context,
    WidgetRef ref,
    CustomerNotification n,
  ) async {
    if (!n.read) {
      final String? err = await ref
          .read(customerNotificationsRepositoryProvider)
          .markRead(n.id);
      if (!context.mounted) {
        return;
      }
      if (err != null) {
        showMndSnackBar(
          context,
          err,
          variant: MndSnackBarVariant.error,
        );
      }
    }

    if (!context.mounted) {
      return;
    }

    final String? tripId = n.tripId;
    if (tripId != null && tripId.isNotEmpty) {
      context.push(AppRoutes.customerRideTrip(tripId));
      return;
    }
    final String? orderId = n.orderId;
    if (orderId != null && orderId.isNotEmpty) {
      context.push('${AppRoutes.customerOrders}/$orderId');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<CustomerNotification>> list =
        ref.watch(customerNotificationsListProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundCanvas,
      appBar: mndPageAppBar(
        title: 'Notifications',
        actions: <Widget>[
          TextButton(
            onPressed: () async {
              final String? err = await ref
                  .read(customerNotificationsRepositoryProvider)
                  .markAllRead();
              if (!context.mounted) {
                return;
              }
              if (err != null) {
                showMndSnackBar(
                  context,
                  err,
                  variant: MndSnackBarVariant.error,
                );
              }
            },
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: list.when(
        loading: () => const Center(child: CircularProgressIndicator.adaptive()),
        error: (Object e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  userFacingError(
                    e,
                    fallback:
                        'Could not load notifications. Please check your connection and try again.',
                  ),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  onPressed: () =>
                      ref.invalidate(customerNotificationsListProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (List<CustomerNotification> items) {
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
                      color: AppColors.brandPrimary.withValues(alpha: 0.35),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No notifications yet',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Order and ride updates will appear here.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            color: AppColors.brandPrimary,
            onRefresh: () async {
              ref.invalidate(customerNotificationsListProvider);
              ref.invalidate(customerUnreadNotificationCountProvider);
              await Future<void>.delayed(const Duration(milliseconds: 400));
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (BuildContext context, int i) {
                final CustomerNotification n = items[i];
                return _NotificationTile(
                  notification: n,
                  timeLabel: _formatTime(n.createdAt),
                  icon: _iconForType(n.type),
                  onTap: () => _onTap(context, ref, n),
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

  final CustomerNotification notification;
  final String timeLabel;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool unread = !notification.read;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: unread
                ? AppColors.brandPrimary.withValues(alpha: 0.06)
                : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: unread
                  ? AppColors.brandPrimary.withValues(alpha: 0.22)
                  : Colors.black.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.brandPrimary, size: 22),
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
                              fontWeight:
                                  unread ? FontWeight.w800 : FontWeight.w600,
                            ),
                          ),
                        ),
                        if (unread)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.brandPrimary,
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
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                    if (timeLabel.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        timeLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
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
