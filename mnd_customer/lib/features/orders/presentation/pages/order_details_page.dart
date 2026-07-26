import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/utils/money_format.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_brand_watermark.dart';
import 'package:mnd_delivery_app/features/orders/domain/entities/customer_order_detail.dart';
import 'package:mnd_delivery_app/features/orders/domain/order_cancellation.dart';
import 'package:mnd_delivery_app/features/orders/domain/order_timeline.dart';
import 'package:mnd_delivery_app/features/orders/presentation/providers/order_detail_provider.dart';
import 'package:mnd_delivery_app/features/orders/presentation/utils/reorder_helper.dart';
import 'package:mnd_delivery_app/features/orders/presentation/widgets/cancel_order_bottom_sheet.dart';
import 'package:mnd_delivery_app/features/orders/presentation/widgets/animated_order_status_tracker.dart';
import 'package:mnd_delivery_app/features/orders/presentation/widgets/store_rating_card.dart';

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
      appBar: AppBar(
        title: const Text('Order details'),
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
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            children: <Widget>[
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppColors.cardRadiusSm),
                  side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        detail.storeName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Tracking ${detail.referenceForDisplay}',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontFamily: 'monospace',
                              letterSpacing: 0.2,
                            ),
                      ),
                      if (formatDate(detail.createdAt) != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          formatDate(detail.createdAt)!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: <Widget>[
                          Text(
                            formatLkr(detail.total),
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryBlue,
                                ),
                          ),
                          const Spacer(),
                          _PaymentChip(label: paymentLabel(detail.paymentMethod)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (detail.riderId != null &&
                          detail.riderId!.trim().isNotEmpty &&
                          OrderTimelineLogic.isActiveForLiveRiderMap(
                            detail.statusRaw,
                          )) ...<Widget>[
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            icon: const Icon(Icons.map_outlined),
                            label: const Text('Track rider on map'),
                            onPressed: () => context.push(
                              AppRoutes.customerOrderLiveTracking(detail.id),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.replay_rounded),
                            label: const Text('Reorder'),
                            onPressed: () =>
                                handleReorder(context, ref, detail),
                          ),
                        ),
                      ] else ...<Widget>[
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            icon: const Icon(Icons.replay_rounded),
                            label: const Text('Reorder'),
                            onPressed: () =>
                                handleReorder(context, ref, detail),
                          ),
                        ),
                      ],
                      if (OrderCancellationPolicy.customerMayCancel(
                        detail.statusRaw,
                      )) ...<Widget>[
                        const SizedBox(height: AppSpacing.sm),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  Theme.of(context).colorScheme.error,
                              side: BorderSide(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                            icon: const Icon(Icons.cancel_outlined),
                            label: const Text('Cancel order'),
                            onPressed: () => showCancelOrderBottomSheet(
                              pageContext: context,
                              detail: detail,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (OrderTimelineLogic.isCancelled(detail.statusRaw)) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                Card(
                  color: Theme.of(context)
                      .colorScheme
                      .errorContainer
                      .withValues(alpha: 0.35),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppColors.cardRadiusSm),
                    side: BorderSide(
                      color: Theme.of(context)
                          .colorScheme
                          .error
                          .withValues(alpha: 0.25),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
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
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              StoreRatingCard(detail: detail),
              const SizedBox(height: AppSpacing.lg),
              AnimatedOrderStatusTracker(statusRaw: detail.statusRaw),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Delivery',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppColors.cardRadiusSm),
                  side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.location_on_outlined,
                        color: AppColors.primaryBlue.withValues(alpha: 0.9),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          detail.deliveryAddress.formatted.isEmpty
                              ? '—'
                              : detail.deliveryAddress.formatted,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (detail.deliveryNote.isNotEmpty || detail.specialInstructions.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                if (detail.deliveryNote.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Icon(Icons.note_outlined, size: 20, color: AppColors.textSecondary),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Note: ${detail.deliveryNote}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (detail.specialInstructions.isNotEmpty)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Icon(Icons.info_outline_rounded, size: 20, color: AppColors.textSecondary),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Instructions: ${detail.specialInstructions}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Items',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ...detail.items.map(
                (OrderLineItem item) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _LineItemTile(item: item, formatLkr: formatLkr),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppColors.cardRadiusSm),
                  side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: <Widget>[
                      _SummaryRow(
                        label: 'Subtotal',
                        value: formatLkr(detail.subtotal),
                      ),
                      if (detail.discount > 0) ...<Widget>[
                        const SizedBox(height: AppSpacing.xs),
                        _SummaryRow(
                          label: 'Discount',
                          value: '- ${formatLkr(detail.discount)}',
                          valueStyle: TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (detail.couponCode != null && detail.couponCode!.isNotEmpty) ...<Widget>[
                        const SizedBox(height: AppSpacing.xs),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Coupon ${detail.couponCode}',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xs),
                      _SummaryRow(
                        label: 'Delivery fee',
                        value: formatLkr(detail.deliveryFee),
                      ),
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
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object err, StackTrace _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'Could not load order.\n$err',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentChip extends StatelessWidget {
  const _PaymentChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.primaryBlue,
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
    final String extrasText = item.extras.isEmpty
        ? ''
        : item.extras.map((e) => e.name).join(', ');
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.cardRadiusSm),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 56,
                height: 56,
                child: item.imageUrl.isNotEmpty
                    ? Image.network(
                        item.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 56,
                          height: 56,
                          color: AppColors.primaryBlue.withValues(alpha: 0.08),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.all(2),
                          child: const FittedBox(
                            fit: BoxFit.contain,
                            child: MndBrandWatermark(
                              mndFontSize: 22,
                              subtitleFontSize: 7,
                              mndOpacity: 0.24,
                              subtitleOpacity: 0.18,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        width: 56,
                        height: 56,
                        color: AppColors.primaryBlue.withValues(alpha: 0.08),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(2),
                        child: const FittedBox(
                          fit: BoxFit.contain,
                          child: MndBrandWatermark(
                            mndFontSize: 22,
                            subtitleFontSize: 7,
                            mndOpacity: 0.24,
                            subtitleOpacity: 0.18,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.productName,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (item.selectedSize.isNotEmpty)
                    Text(
                      item.selectedSize,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  if (extrasText.isNotEmpty)
                    Text(
                      extrasText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '×${item.quantity}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            Text(
              formatLkr(item.lineTotal),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
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
          style: emphasize ? Theme.of(context).textTheme.titleMedium : base,
        ),
        const Spacer(),
        Text(
          value,
          style: valueStyle ?? base,
        ),
      ],
    );
  }
}
