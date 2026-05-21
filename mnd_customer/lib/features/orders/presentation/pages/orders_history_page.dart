import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/app/providers/firebase_providers.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/features/orders/domain/entities/customer_order_summary.dart';
import 'package:mnd_delivery_app/features/orders/presentation/providers/customer_orders_provider.dart';

class OrdersHistoryPage extends ConsumerWidget {
  const OrdersHistoryPage({super.key});

  static String _formatLkr(int amount) {
    final String s = amount.toString();
    if (s.length <= 3) {
      return 'LKR $s';
    }
    final StringBuffer b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) {
        b.write(',');
      }
      b.write(s[i]);
    }
    return 'LKR $b';
  }

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
    final AsyncValue<List<CustomerOrderSummary>> orders = ref.watch(customerOrdersStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My orders'),
      ),
      body: auth.when(
        data: (User? user) {
          if (user == null) {
            return _SignInPrompt(
              onSignIn: () => context.push(AppRoutes.login),
            );
          }
          return orders.when(
            data: (List<CustomerOrderSummary> list) {
              final List<CustomerOrderSummary> active =
                  list.where((CustomerOrderSummary o) => !o.isCompleted).toList();
              final List<CustomerOrderSummary> completed =
                  list.where((CustomerOrderSummary o) => o.isCompleted).toList();

              if (list.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 56,
                          color: Colors.black.withValues(alpha: 0.35),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'No orders yet',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'When you place an order, it will show up here.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.black54,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
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
                  _SectionTitle(label: 'Active', count: active.length),
                  const SizedBox(height: AppSpacing.sm),
                  if (active.isEmpty)
                    _EmptyHint(text: 'No active orders right now.')
                  else
                    ...active.map(
                      (CustomerOrderSummary o) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _OrderCard(
                          order: o,
                          formatTotal: _formatLkr,
                          formatDate: _formatDate,
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                  _SectionTitle(label: 'Completed', count: completed.length),
                  const SizedBox(height: AppSpacing.sm),
                  if (completed.isEmpty)
                    _EmptyHint(text: 'No completed orders yet.')
                  else
                    ...completed.map(
                      (CustomerOrderSummary o) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _OrderCard(
                          order: o,
                          formatTotal: _formatLkr,
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

class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.lock_outline_rounded,
              size: 48,
              color: Colors.black.withValues(alpha: 0.4),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Sign in to see your orders',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Your order history is saved to your account.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: onSignIn,
              child: const Text('Sign in'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.label,
    required this.count,
  });

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
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
              color: Colors.black45,
            ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.formatTotal,
    required this.formatDate,
  });

  final CustomerOrderSummary order;
  final String Function(int) formatTotal;
  final String? Function(DateTime?) formatDate;

  @override
  Widget build(BuildContext context) {
    final Color chipBg = order.isCompleted
        ? Colors.black.withValues(alpha: 0.06)
        : AppColors.primaryBlue.withValues(alpha: 0.12);
    final Color chipFg = order.isCompleted
        ? Colors.black54
        : AppColors.primaryBlue;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.push('${AppRoutes.customerOrders}/${order.id}'),
      child: Card(
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      order.storeName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: chipBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      order.displayStatus,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: chipFg,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                formatTotal(order.totalLkr),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              if (formatDate(order.createdAt) != null) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  formatDate(order.createdAt)!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.black54,
                      ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Tracking ${order.referenceForDisplay}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.black38,
                      fontFamily: 'monospace',
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
