import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/core/constants/route_paths.dart';
import 'package:mnd_rider/core/utils/user_facing_error.dart';
import 'package:mnd_rider/core/widgets/rider_empty_state.dart';
import 'package:mnd_rider/core/widgets/rider_error_state.dart';
import 'package:mnd_rider/core/widgets/rider_skeleton.dart';
import 'package:mnd_rider/features/notifications/data/rider_notifications_repository.dart';
import 'package:mnd_rider/features/shell/presentation/providers/rider_shell_tab_provider.dart';

/// Wallet/cash-hold notification types written by functions/src/riderNotify.ts
/// — none of these carry an orderId/tripId, so they need their own icon and
/// tap target (the Earnings tab) instead of falling through to the generic
/// bell icon and a no-op tap.
const Set<String> _kWalletNotificationTypes = <String>{
  'withdrawal_settled',
  'cash_hold_started',
  'cash_settlement_confirmed',
  'cash_settlement_rejected',
};

class RiderNotificationsPage extends ConsumerWidget {
  const RiderNotificationsPage({super.key});

  IconData _iconFor(String type) {
    switch (type) {
      case 'new_delivery_request':
        return Icons.delivery_dining_rounded;
      case 'order_cancelled':
        return Icons.cancel_outlined;
      case 'delivery_completed':
      case 'earnings':
        return Icons.payments_outlined;
      case 'ride_update':
        return Icons.two_wheeler_rounded;
      default:
        if (_kWalletNotificationTypes.contains(type)) {
          return Icons.account_balance_wallet_outlined;
        }
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<RiderInboxNotification>> async =
        ref.watch(riderInboxNotificationsProvider);
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: <Widget>[
          TextButton(
            onPressed: () async {
              final List<RiderInboxNotification> rows =
                  async.valueOrNull ?? const <RiderInboxNotification>[];
              final List<String> unread = rows
                  .where((RiderInboxNotification n) => !n.read)
                  .map((RiderInboxNotification n) => n.id)
                  .toList(growable: false);
              if (unread.isEmpty) {
                return;
              }
              await ref
                  .read(riderNotificationsRepositoryProvider)
                  .markAllRead(unread);
            },
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: async.when(
        loading: () => const RiderSkeletonList(count: 6),
        error: (Object e, _) => Center(
          child: RiderErrorState(
            message: userFacingError(e),
            onRetry: () => ref.invalidate(riderInboxNotificationsProvider),
          ),
        ),
        data: (List<RiderInboxNotification> rows) {
          if (rows.isEmpty) {
            return const RiderEmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'No notifications yet',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (BuildContext context, int i) {
              final RiderInboxNotification n = rows[i];
              return Material(
                color: n.read
                    ? cs.surface
                    : AppColors.primaryBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () async {
                    if (!n.read) {
                      await ref
                          .read(riderNotificationsRepositoryProvider)
                          .markRead(n.id);
                    }
                    if (!context.mounted) {
                      return;
                    }
                    final String? orderId = n.orderId?.trim();
                    final String? tripId = n.tripId?.trim();
                    if (orderId != null && orderId.isNotEmpty) {
                      context.push('${RoutePaths.orderDetail}/$orderId');
                    } else if (tripId != null && tripId.isNotEmpty) {
                      context.push('${RoutePaths.ride}/$tripId');
                    } else if (_kWalletNotificationTypes.contains(n.type)) {
                      ref.read(riderShellTabIndexProvider.notifier).state = 2;
                      context.go(RoutePaths.shell);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(
                          _iconFor(n.type),
                          color: AppColors.primaryBlue,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                n.title.isEmpty ? 'Update' : n.title,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (n.body.isNotEmpty) ...<Widget>[
                                const SizedBox(height: 4),
                                Text(
                                  n.body,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                              if (n.createdAt != null) ...<Widget>[
                                const SizedBox(height: 6),
                                Text(
                                  n.createdAt!.toLocal().toString().split('.').first,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (!n.read)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 6),
                            decoration: const BoxDecoration(
                              color: AppColors.primaryBlue,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
