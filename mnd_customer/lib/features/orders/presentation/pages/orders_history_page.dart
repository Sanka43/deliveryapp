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
import 'package:mnd_delivery_app/core/utils/user_facing_error.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_gradient_badge.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_premium_card.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_section_header.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_empty_state.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_page_app_bar.dart';
import 'package:mnd_delivery_app/features/auth/presentation/providers/guest_browsing_provider.dart';
import 'package:mnd_delivery_app/features/orders/domain/entities/customer_order_summary.dart';
import 'package:mnd_delivery_app/features/orders/domain/order_timeline.dart';
import 'package:mnd_delivery_app/features/orders/presentation/providers/customer_orders_provider.dart';
import 'package:mnd_delivery_app/features/orders/presentation/utils/orders_load_error.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/floating_glass_nav_bar.dart';
import 'package:mnd_delivery_app/l10n/generated/app_localizations.dart';

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
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundCanvas,
      appBar: mndPageAppBar(title: l10n.ordersHistoryTitle, implyLeading: false),
      body: auth.when(
        data: (User? user) {
          if (user == null) {
            return MndEmptyState(
              icon: Icons.lock_outline_rounded,
              title: l10n.ordersSignInTitle,
              subtitle: l10n.ordersSignInSubtitle,
              actionLabel: l10n.actionSignIn,
              onAction: () {
                ref.read(guestBrowsingProvider.notifier).state = false;
                ref.read(postAuthRedirectProvider.notifier).state =
                    AppRoutes.customerOrders;
                context.go(AppRoutes.login);
              },
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(customerOrdersStreamProvider);
            },
            child: orders.when(
              data: (List<CustomerOrderSummary> list) {
                // draft_payment orders are created the moment an online
                // checkout starts, before payment is confirmed — if the
                // customer abandons payment, this draft never becomes a
                // real order (no `placed` status, no cancel option), so it
                // must never show up in their order history.
                final List<CustomerOrderSummary> visible = list
                    .where(
                      (CustomerOrderSummary o) =>
                          o.statusRaw.toLowerCase().trim() != 'draft_payment',
                    )
                    .toList();
                final List<CustomerOrderSummary> active = visible
                    .where((CustomerOrderSummary o) => !o.isCompleted)
                    .toList();
                final List<CustomerOrderSummary> completed = visible
                    .where((CustomerOrderSummary o) => o.isCompleted)
                    .toList();

                if (visible.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: <Widget>[
                      SizedBox(
                        height: MediaQuery.sizeOf(context).height * 0.5,
                        child: MndEmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: l10n.ordersEmptyTitle,
                          subtitle: l10n.ordersEmptySubtitle,
                          actionLabel: l10n.homeHeroOrderFood,
                          onAction: () => context.go(AppRoutes.customerFood),
                        ),
                      ),
                    ],
                  );
                }

                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    floatingNavTotalHeight(context),
                  ),
                  children: <Widget>[
                    MndSectionHeader(
                      title: l10n.ordersActiveHeader(active.length),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (active.isEmpty)
                      _EmptyHint(text: l10n.ordersNoActiveHint)
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
                      title: l10n.ordersCompletedHeader(completed.length),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (completed.isEmpty)
                      _EmptyHint(text: l10n.ordersNoCompletedHint)
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
              error: (Object err, StackTrace _) => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: <Widget>[
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.5,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text(
                              ordersLoadErrorMessage(
                                err,
                                fallback: l10n.ordersLoadErrorFallback,
                              ),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            FilledButton(
                              onPressed: () => ref.invalidate(
                                customerOrdersStreamProvider,
                              ),
                              child: Text(l10n.actionRetry),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object err, StackTrace _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              userFacingError(
                err,
                fallback: l10n.ordersVerifySignInErrorFallback,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactCardAction extends StatelessWidget {
  const _CompactCardAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: 2,
        ),
      ),
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
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
        OrderTimelineLogic.isActiveForLiveRiderMap(
          order.statusRaw,
          isSelfPickup: order.isSelfPickup,
        );

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
          Row(
            children: <Widget>[
              Text(
                MoneyFormat.lkr(order.subtotalLkr, showDecimals: false),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              if (formatDate(order.createdAt) != null) ...<Widget>[
                const Spacer(),
                Text(
                  formatDate(order.createdAt)!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  AppLocalizations.of(context)
                      .ordersTrackingLabel(order.referenceForDisplay),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                        letterSpacing: 0.2,
                      ),
                ),
              ),
              if (canTrack || order.canRateStore)
                Wrap(
                  spacing: AppSpacing.xs,
                  children: <Widget>[
                    if (order.canRateStore)
                      _CompactCardAction(
                        icon: Icons.star_outline_rounded,
                        label: AppLocalizations.of(context).actionRate,
                        onPressed: () => context.push(
                          '${AppRoutes.customerOrders}/${order.id}',
                        ),
                      ),
                    if (canTrack)
                      _CompactCardAction(
                        icon: Icons.map_outlined,
                        label: AppLocalizations.of(context).actionTrack,
                        onPressed: () => context.push(
                          AppRoutes.customerOrderLiveTracking(order.id),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
