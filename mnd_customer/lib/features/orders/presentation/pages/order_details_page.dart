import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/utils/money_format.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_premium_card.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_page_app_bar.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_snackbar.dart';
import 'package:mnd_delivery_app/core/utils/payhere_native_launcher.dart';
import 'package:mnd_delivery_app/core/utils/user_facing_error.dart';
import 'package:mnd_delivery_app/features/orders/data/order_placement_repository.dart';
import 'package:mnd_delivery_app/features/orders/domain/entities/customer_order_detail.dart';
import 'package:mnd_delivery_app/features/orders/domain/order_cancellation.dart';
import 'package:mnd_delivery_app/features/orders/domain/order_timeline.dart';
import 'package:mnd_delivery_app/features/orders/presentation/providers/order_detail_provider.dart';
import 'package:mnd_delivery_app/features/orders/presentation/providers/order_placement_repository_provider.dart';
import 'package:mnd_delivery_app/features/orders/presentation/utils/orders_load_error.dart';
import 'package:mnd_delivery_app/features/orders/presentation/widgets/cancel_order_bottom_sheet.dart';
import 'package:mnd_delivery_app/features/orders/presentation/widgets/animated_order_status_tracker.dart';
import 'package:mnd_delivery_app/features/orders/presentation/widgets/store_rating_card.dart';
import 'package:mnd_delivery_app/features/orders/presentation/widgets/rider_rating_card.dart';

class OrderDetailsPage extends ConsumerWidget {
  const OrderDetailsPage({super.key, required this.orderId});

  final String orderId;

  static String formatLkr(int amount) =>
      MoneyFormat.lkr(amount, showDecimals: false);

  static String? formatDate(DateTime? d) {
    if (d == null) {
      return null;
    }
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} · ${two(d.hour)}:${two(d.minute)}';
  }

  static String paymentLabel(String raw) {
    final String key = raw.toLowerCase().trim();
    switch (key) {
      case 'cashondelivery':
      case 'cash_on_delivery':
        return 'Cash on delivery';
      case 'payhere':
        return 'Paid online';
      case 'card':
        return 'Card';
      case 'wallet':
        return 'Wallet';
      default:
        if (raw.isEmpty) {
          return '—';
        }
        return raw;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<CustomerOrderDetail?> async =
        ref.watch(orderDetailStreamProvider(orderId));

    return Scaffold(
      backgroundColor: AppColors.backgroundCanvas,
      appBar: mndPageAppBar(
        title: 'Order details',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.customerOrders);
            }
          },
        ),
      ),
      body: async.when(
        data: (CustomerOrderDetail? detail) {
          if (detail == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  'Order not found or you do not have access.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            );
          }
          final bool showTrackRider = detail.riderId != null &&
              detail.riderId!.trim().isNotEmpty &&
              OrderTimelineLogic.isActiveForLiveRiderMap(
                detail.statusRaw,
                isSelfPickup: detail.isSelfPickup,
              );
          final bool showCancel = OrderCancellationPolicy.customerMayCancel(
            detail.statusRaw,
          );
          final String paymentMethodKey =
              detail.paymentMethod.toLowerCase().trim();
          final bool showPayOnline =
              (paymentMethodKey == 'cashondelivery' ||
                  paymentMethodKey == 'cash_on_delivery') &&
              !detail.isPaid &&
              !OrderTimelineLogic.isCancelled(detail.statusRaw) &&
              detail.statusRaw.trim().toLowerCase() != 'delivered';

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.lg,
            ),
            children: <Widget>[
              _HeroOrderCard(
                detail: detail,
                formatLkr: formatLkr,
                showPayOnline: showPayOnline,
              ),
              if (showTrackRider) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                MndPremiumCard(
                  borderRadius: AppColors.cardRadiusLg,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Track rider on map'),
                      onPressed: () => context.push(
                        AppRoutes.customerOrderLiveTracking(
                          detail.id,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              if (OrderTimelineLogic.isCancelled(detail.statusRaw)) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .errorContainer
                        .withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(AppColors.cardRadiusLg),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .error
                          .withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(
                            Icons.cancel_rounded,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'Order cancelled',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      if (detail.resolvedCancellationLabel != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Reason: ${detail.resolvedCancellationLabel}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                      if (detail.cancellationReasonDetail != null &&
                          detail.cancellationReasonDetail!
                              .trim()
                              .isNotEmpty) ...<Widget>[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          detail.cancellationReasonDetail!.trim(),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if (StoreRatingCard.isRateable(detail)) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                StoreRatingCard(detail: detail),
              ],
              if (RiderRatingCard.isRateable(detail)) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                RiderRatingCard(detail: detail),
              ],
              const SizedBox(height: AppSpacing.sm),
              if (detail.isSelfPickup) ...<Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Self pickup',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              MndPremiumCard(
                borderRadius: AppColors.cardRadiusLg,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                ),
                child: Column(
                  children: <Widget>[
                    for (int i = 0; i < detail.items.length; i++) ...<Widget>[
                      if (i > 0) const Divider(height: 1),
                      _LineItemTile(
                        item: detail.items[i],
                        formatLkr: formatLkr,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              MndPremiumCard(
                borderRadius: AppColors.cardRadiusLg,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            detail.isSelfPickup
                                ? Icons.storefront_rounded
                                : Icons.location_on_rounded,
                            color: AppColors.primaryBlue,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  detail.isSelfPickup
                                      ? 'Collect at'
                                      : 'Delivery address',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  detail.deliveryAddress.formatted.isEmpty
                                      ? '—'
                                      : detail.deliveryAddress.formatted,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (detail.deliveryNote.isNotEmpty ||
                        detail.specialInstructions.isNotEmpty) ...<Widget>[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
                        child: Divider(height: 1),
                      ),
                      if (detail.deliveryNote.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Icon(
                                Icons.note_outlined,
                                size: 18,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  'Note: ${detail.deliveryNote}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (detail.specialInstructions.isNotEmpty)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Icon(
                              Icons.info_outline_rounded,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'Instructions: ${detail.specialInstructions}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                    ],
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      child: Divider(height: 1),
                    ),
                    if (detail.isOnlinePayment) ...<Widget>[
                      Row(
                        children: <Widget>[
                          Text(
                            'Payment status',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const Spacer(),
                          _PaymentChip(
                            label: detail.isPaid ? 'Paid' : 'Payment pending',
                            color: detail.isPaid
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                    ],
                    _SummaryRow(
                      label: 'Subtotal',
                      value: formatLkr(detail.subtotal),
                    ),
                    if (detail.discount > 0) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      _SummaryRow(
                        label: 'Discount',
                        value: '- ${formatLkr(detail.discount)}',
                        valueStyle: const TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (detail.couponCode != null &&
                        detail.couponCode!.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Coupon ${detail.couponCode}',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    _SummaryRow(
                      label:
                          detail.isSelfPickup ? 'Pickup fee' : 'Delivery fee',
                      value: formatLkr(detail.deliveryFee),
                    ),
                    if (detail.serviceCharge > 0) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      _SummaryRow(
                        label: 'Service charge',
                        value: formatLkr(detail.serviceCharge),
                      ),
                    ],
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      child: Divider(height: 1),
                    ),
                    _SummaryRow(
                      label: 'Total',
                      value: formatLkr(detail.total),
                      emphasize: true,
                    ),
                  ],
                ),
              ),
              if (showCancel)
                _CancelOrderBar(
                  createdAt: detail.createdAt,
                  onTap: () => showCancelOrderBottomSheet(
                    pageContext: context,
                    detail: detail,
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object err, StackTrace _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  ordersLoadErrorMessage(
                    err,
                    fallback: 'Could not load order.',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  onPressed: () =>
                      ref.invalidate(orderDetailStreamProvider(orderId)),
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

/// Lets the customer cancel within a 90s grace period after the order was
/// placed, with a live countdown; disappears once the window has passed.
class _CancelOrderBar extends StatefulWidget {
  const _CancelOrderBar({required this.onTap, required this.createdAt});

  final VoidCallback onTap;
  final DateTime? createdAt;

  static const int _windowSeconds = 90;

  @override
  State<_CancelOrderBar> createState() => _CancelOrderBarState();
}

class _CancelOrderBarState extends State<_CancelOrderBar> {
  Timer? _timer;
  late int _secondsLeft;

  @override
  void initState() {
    super.initState();
    _secondsLeft = _computeSecondsLeft();
    if (_secondsLeft > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        final int next = _computeSecondsLeft();
        setState(() => _secondsLeft = next);
        if (next <= 0) {
          _timer?.cancel();
        }
      });
    }
  }

  int _computeSecondsLeft() {
    final DateTime? createdAt = widget.createdAt;
    if (createdAt == null) {
      return 0;
    }
    final int elapsed = DateTime.now().difference(createdAt).inSeconds;
    return (_CancelOrderBar._windowSeconds - elapsed)
        .clamp(0, _CancelOrderBar._windowSeconds);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_secondsLeft <= 0) {
      return const SizedBox.shrink();
    }
    final Color errorColor = Theme.of(context).colorScheme.error;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: SizedBox(
        width: double.infinity,
        child: TextButton(
          style: TextButton.styleFrom(
            foregroundColor: errorColor,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: widget.onTap,
          child: Text('Cancel Order (${_secondsLeft}s)'),
        ),
      ),
    );
  }
}

/// Lets a customer who placed an order as Cash on Delivery pay online for it
/// instead, at any point before it's delivered. The order is only marked
/// paid once PayHere confirms payment server-side — `orderDetailStreamProvider`
/// picks that up live, so this widget only needs to reflect the in-flight
/// payment attempt, not the final result.
class _PayOnlineAction extends ConsumerStatefulWidget {
  const _PayOnlineAction({required this.orderId});

  final String orderId;

  @override
  ConsumerState<_PayOnlineAction> createState() => _PayOnlineActionState();
}

class _PayOnlineActionState extends ConsumerState<_PayOnlineAction> {
  bool _submitting = false;

  Future<void> _payOnline() async {
    setState(() => _submitting = true);
    try {
      final OrderPlacementRepository repo =
          ref.read(orderPlacementRepositoryProvider);
      final OrderPayHereCheckout checkout =
          await repo.createPayHereCheckoutForExistingOrder(
        orderId: widget.orderId,
      );
      if (!mounted) {
        return;
      }
      final PayHereNativeResult result = await launchPayHerePayment(
        fields: checkout.fields,
        sandbox: checkout.sandbox,
        checkoutPageUrl: checkout.checkoutPageUrl,
      );
      if (!mounted) {
        return;
      }
      switch (result.status) {
        case PayHereNativeStatus.completed:
          showMndSnackBar(
            context,
            'Payment received — updating your order…',
            variant: MndSnackBarVariant.success,
          );
          break;
        case PayHereNativeStatus.opened:
          // The browser is navigating away to PayHere's checkout page —
          // this snackbar will rarely be visible before unload, but covers
          // the case where the redirect is somehow interrupted.
          showMndSnackBar(
            context,
            'Redirecting to payment…',
            variant: MndSnackBarVariant.success,
          );
          break;
        case PayHereNativeStatus.dismissed:
          showMndSnackBar(
            context,
            'Payment cancelled.',
            variant: MndSnackBarVariant.warning,
          );
          break;
        case PayHereNativeStatus.error:
          showMndSnackBar(
            context,
            result.errorMessage ?? 'Payment failed.',
            variant: MndSnackBarVariant.error,
          );
          break;
      }
    } catch (e) {
      if (mounted) {
        showMndSnackBar(
          context,
          userFacingError(e, fallback: 'Could not start payment.'),
          variant: MndSnackBarVariant.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: _submitting ? null : _payOnline,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _submitting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.brandPrimary,
                      ),
                    )
                  : const Icon(
                      Icons.credit_card_rounded,
                      size: 15,
                      color: AppColors.brandPrimary,
                    ),
              const SizedBox(width: 6),
              Text(
                _submitting ? 'Starting…' : 'Pay online',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.brandPrimary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroOrderCard extends StatelessWidget {
  const _HeroOrderCard({
    required this.detail,
    required this.formatLkr,
    required this.showPayOnline,
  });

  final CustomerOrderDetail detail;
  final String Function(int) formatLkr;
  final bool showPayOnline;

  @override
  Widget build(BuildContext context) {
    final String? dateLabel = OrderDetailsPage.formatDate(detail.createdAt);
    final String chipLabel = detail.isOnlinePayment
        ? (detail.isPaid ? 'Paid' : 'Payment pending')
        : OrderDetailsPage.paymentLabel(detail.paymentMethod);
    final Color chipDot = detail.isOnlinePayment
        ? (detail.isPaid ? AppColors.success : AppColors.warning)
        : Colors.white;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppColors.cardRadiusLg + 4),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppColors.cardRadiusLg + 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration:
                  const BoxDecoration(gradient: AppColors.brandGradient),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.storefront_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              detail.storeName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: <Widget>[
                                Icon(
                                  Icons.confirmation_number_outlined,
                                  size: 14,
                                  color: Colors.white.withValues(alpha: 0.75),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  detail.referenceForDisplay,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Colors.white
                                            .withValues(alpha: 0.85),
                                        fontWeight: FontWeight.w700,
                                        fontFamily: 'monospace',
                                        letterSpacing: 0.2,
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (showPayOnline) ...<Widget>[
                        const SizedBox(width: AppSpacing.sm),
                        _PayOnlineAction(orderId: detail.id),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                      height: 1, color: Colors.white.withValues(alpha: 0.18)),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Total',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.75),
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              formatLkr(detail.total),
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            if (dateLabel != null) ...<Widget>[
                              const SizedBox(height: 2),
                              Text(
                                dateLabel,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color:
                                          Colors.white.withValues(alpha: 0.7),
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: chipDot,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              chipLabel,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              color: AppColors.surfaceElevated,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: AnimatedOrderStatusTracker(
                statusRaw: detail.statusRaw,
                isSelfPickup: detail.isSelfPickup,
                embedded: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentChip extends StatelessWidget {
  const _PaymentChip({required this.label, this.color = AppColors.primaryBlue});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _LineItemTile extends StatelessWidget {
  const _LineItemTile({
    required this.item,
    required this.formatLkr,
  });

  final OrderLineItem item;
  final String Function(int) formatLkr;

  @override
  Widget build(BuildContext context) {
    final String tagsText = <String>[
      if (item.selectedSize.isNotEmpty) item.selectedSize,
      ...item.extras.map((e) => e.name),
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${item.quantity}×',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (tagsText.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    tagsText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            formatLkr(item.lineTotal),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryBlue,
                ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasize = false,
    this.valueStyle,
  });

  final String label;
  final String value;
  final bool emphasize;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    final TextStyle? base = emphasize
        ? Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            )
        : Theme.of(context).textTheme.bodyMedium;
    return Row(
      children: <Widget>[
        Text(
          label,
          style: emphasize
              ? Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  )
              : base,
        ),
        const Spacer(),
        Text(
          value,
          style: valueStyle ??
              (emphasize ? base?.copyWith(color: AppColors.primaryBlue) : base),
        ),
      ],
    );
  }
}
