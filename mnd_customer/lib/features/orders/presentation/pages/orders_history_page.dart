import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/app/providers/firebase_providers.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/utils/money_format.dart';
import 'package:mnd_delivery_app/core/utils/order_status_style.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_gradient_badge.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_premium_card.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_section_header.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_empty_state.dart';
import 'package:mnd_delivery_app/features/orders/domain/entities/customer_order_summary.dart';
import 'package:mnd_delivery_app/features/orders/domain/order_timeline.dart';
import 'package:mnd_delivery_app/features/orders/presentation/providers/customer_orders_provider.dart';

class OrdersHistoryPage extends ConsumerWidget {
  const OrdersHistoryPage({super.key});

  static String? _formatDate(DateTime? d) {
    if (d == null) {
      return null;
    }
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} · ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<User?> auth = ref.watch(authStateUserProvider);
    final AsyncValue<List<CustomerOrderSummary>> orders =
        ref.watch(customerOrdersStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundCanvas,
      appBar: AppBar(
        title: const Text('My orders'),
      ),
      body: auth.when(
        data: (User? user) {
          if (user == null) {
            return MndEmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Sign in to see your orders',
              subtitle: 'Your order history is saved to your account.',
              actionLabel: 'Sign in',
              onAction: () => context.push(AppRoutes.login),
            );
          }
          return orders.when(
            data: (List<CustomerOrderSummary> list) {
              final List<CustomerOrderSummary> active = list
                  .where((CustomerOrderSummary o) => !o.isCompleted)
                  .toList();
              final List<CustomerOrderSummary> completed = list
                  .where((CustomerOrderSummary o) => o.isCompleted)
                  .toList();

              if (list.isEmpty) {
                return MndEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No orders yet',
                  subtitle:
                      'When you place an order, it will show up here.',
                  actionLabel: 'Order food',
                  onAction: () => context.go(AppRoutes.customerFood),
                );
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.xl,
                ),
                children: <Widget>[
                  MndSectionHeader(
                    title: 'Active (${active.length})',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (active.isEmpty)
                    const _EmptyHint(text: 'No active orders right now.')
                  else
                    ...active.map(
                      (CustomerOrderSummary o) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _OrderCard(
                          order: o,
                          formatDate: _formatDate,
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                  MndSectionHeader(
                    title: 'Completed (${completed.length})',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (completed.isEmpty)
                    const _EmptyHint(text: 'No completed orders yet.')
                  else
                    ...completed.map(
                      (CustomerOrderSummary o) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _OrderCard(
                          order: o,
                          formatDate: _formatDate,
                        ),
                      ),
                    ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object err, StackTrace _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  'Could not load orders.\n$err',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object err, StackTrace _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'Could not verify sign-in.\n$err',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.formatDate,
  });

  final CustomerOrderSummary order;
  final String? Function(DateTime?) formatDate;

  @override
  Widget build(BuildContext context) {
    final bool canTrack =
        !order.isCompleted &&
        OrderTimelineLogic.isActiveForLiveRiderMap(order.statusRaw);

    return MndPremiumCard(
      borderRadius: AppColors.cardRadiusSm,
      onTap: () => context.push('${AppRoutes.customerOrders}/${order.id}'),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  order.storeName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              MndGradientBadge(
                label: order.displayStatus,
                style: OrderStatusStyle.badgeStyleFor(order.statusRaw),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            MoneyFormat.lkr(order.totalLkr, showDecimals: false),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (formatDate(order.createdAt) != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              formatDate(order.createdAt)!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Tracking ${order.referenceForDisplay}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 0.2,
                ),
          ),
          if (canTrack || order.canRateStore) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: AppSpacing.sm,
                children: <Widget>[
                  if (order.canRateStore)
                    TextButton.icon(
                      onPressed: () => context.push(
                        '${AppRoutes.customerOrders}/${order.id}',
                      ),
                      icon: const Icon(Icons.star_outline_rounded, size: 18),
                      label: const Text('Rate'),
                    ),
                  if (canTrack)
                    TextButton.icon(
                      onPressed: () => context.push(
                        AppRoutes.customerOrderLiveTracking(order.id),
                      ),
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: const Text('Track'),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
