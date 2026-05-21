import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/features/cart/presentation/providers/cart_provider.dart';

/// Bottom summary strip: item count + subtotal + "View cart" (reference-style UI).
///
/// If [filterStoreId] is set, the bar only shows when the cart is non-empty and
/// belongs to that store (first line item [storeId] match).
class FloatingCartSummaryBar extends ConsumerWidget {
  const FloatingCartSummaryBar({
    required this.onViewCart,
    this.filterStoreId,
    super.key,
  });

  final VoidCallback onViewCart;

  /// When null, shows for any non-empty cart.
  final String? filterStoreId;

  static const Color _barBackground = AppColors.cartBarBackground;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CartState cart = ref.watch(cartProvider);
    if (cart.isEmpty) {
      return const SizedBox.shrink();
    }
    if (filterStoreId != null && cart.items.first.storeId != filterStoreId) {
      return const SizedBox.shrink();
    }

    final int count = cart.itemCount;
    final int payable = cart.subtotal - cart.discount;
    final String itemLabel = count == 1 ? '1 Item' : '$count Items';

    return Material(
      elevation: 8,
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: _barBackground,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    itemLabel,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatLkrDisplay(payable),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                  ),
                ],
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 2,
                shadowColor: AppColors.brandPrimary.withValues(alpha: 0.45),
              ),
              onPressed: onViewCart,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'View cart',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatLkrDisplay(int amount) {
  final String digits = (amount < 0 ? 0 : amount).toString();
  final String rev = digits.split('').reversed.join();
  final StringBuffer buf = StringBuffer();
  for (int i = 0; i < rev.length; i++) {
    if (i > 0 && i % 3 == 0) {
      buf.write(',');
    }
    buf.write(rev[i]);
  }
  final String grouped = buf.toString().split('').reversed.join();
  return 'LKR $grouped.00';
}
