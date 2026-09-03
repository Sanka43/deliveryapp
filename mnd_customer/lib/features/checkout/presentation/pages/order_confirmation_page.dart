import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_premium_card.dart';

/// Shown right after a successful order placement, before landing on order
/// details. Gives the customer a clear confirmation moment instead of a
/// snackbar-and-navigate.
class OrderConfirmationPage extends StatelessWidget {
  const OrderConfirmationPage({
    required this.orderId,
    this.trackingNumber,
    required this.totalLabel,
    required this.isPickup,
    super.key,
  });

  final String orderId;
  final String? trackingNumber;
  final String totalLabel;
  final bool isPickup;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final String? tn = trackingNumber?.trim();

    return Scaffold(
      backgroundColor: AppColors.backgroundCanvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 56,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Order placed!',
                style: text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                tn != null && tn.isNotEmpty
                    ? 'Thank you — your order is confirmed with tracking $tn.'
                    : 'Thank you — your order has been confirmed.',
                style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              MndPremiumCard(
                borderRadius: AppColors.cardRadiusMd,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: <Widget>[
                    _SummaryLine(
                      label: 'Order total',
                      value: totalLabel,
                      emphasize: true,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _SummaryLine(
                      label: isPickup ? 'Fulfillment' : 'Delivery',
                      value: isPickup ? 'Self pickup' : 'Home delivery',
                    ),
                    if (tn != null && tn.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      _SummaryLine(label: 'Tracking number', value: tn),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () =>
                      context.go('${AppRoutes.customerOrders}/$orderId'),
                  child: const Text('View order details'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.go(AppRoutes.customer),
                  child: const Text('Continue shopping'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final TextStyle? valueStyle = emphasize
        ? text.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.primaryBlue,
          )
        : text.bodyMedium?.copyWith(fontWeight: FontWeight.w700);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(
          label,
          style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        Text(value, style: valueStyle),
      ],
    );
  }
}
