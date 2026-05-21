import 'package:flutter/material.dart';
import 'package:mnd_shop/core/constants/app_colors.dart';
import 'package:mnd_shop/features/dashboard/domain/vendor_pending_order.dart';

/// Full-screen order details. [readOnly] hides accept/reject (e.g. kitchen / ready pipeline).
class IncomingVendorOrderPage extends StatelessWidget {
  const IncomingVendorOrderPage({
    super.key,
    required this.order,
    this.readOnly = false,
  });

  final VendorPendingOrder order;

  /// When true, body is view-only; close/dismiss does not return accept/reject flags.
  final bool readOnly;

  static String _money(double v) => 'Rs. ${v.toStringAsFixed(2)}';

  static String _statusBannerLabel(String statusKey) {
    switch (statusKey.toLowerCase()) {
      case 'placed':
        return 'Incoming order';
      case 'confirmed':
      case 'preparing':
        return 'In kitchen';
      case 'ready':
        return 'Ready for pickup';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Order';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Dismiss',
          onPressed: () =>
              readOnly ? Navigator.of(context).pop<void>() : Navigator.of(context).pop<bool?>(null),
        ),
        title: const Text('Order details'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, readOnly ? 24 : 100),
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                colors: <Color>[
                  AppColors.primaryBlue.withValues(alpha: 0.95),
                  AppColors.primaryBlue.withValues(alpha: 0.78),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    readOnly ? _statusBannerLabel(order.statusKey) : 'Incoming Order',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 6),
                Text(
                  order.referenceForDisplay,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                  ),
                ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (order.customerPhone.isNotEmpty)
            Text(
              order.customerPhone,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          const SizedBox(height: 6),
          const SizedBox(height: 20),
          _TotalBanner(amount: _money(order.total)),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.schedule, size: 22, color: cs.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Placed',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(order.placedAtLabel, style: theme.textTheme.bodyLarge),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.22)),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: cs.shadow.withValues(alpha: 0.05),
                  blurRadius: 36,
                  spreadRadius: -8,
                  offset: const Offset(0, 14),
                ),
                BoxShadow(
                  color: cs.shadow.withValues(alpha: 0.07),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Items',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(order.itemsSummary, style: theme.textTheme.bodyLarge),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: readOnly
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop<bool>(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: cs.error,
                          side: BorderSide(color: cs.error.withValues(alpha: 0.85)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop<bool>(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.openGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Accept'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _TotalBanner extends StatelessWidget {
  const _TotalBanner({required this.amount});

  final String amount;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primaryBlue.withValues(alpha: 0.25),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: <Widget>[
            Icon(Icons.payments_outlined, color: AppColors.primaryBlue),
            const SizedBox(width: 12),
            Text(
              'Order total',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              amount,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.primaryBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
