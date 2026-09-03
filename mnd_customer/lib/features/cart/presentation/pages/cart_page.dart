import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/app/providers/firebase_providers.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/widgets/sign_in_required_prompt.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/utils/money_format.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_confirm_dialog.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_empty_state.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_premium_card.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_section_header.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_network_image.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_page_app_bar.dart';
import 'package:mnd_delivery_app/features/cart/presentation/providers/cart_provider.dart';

class CartPage extends ConsumerStatefulWidget {
  const CartPage({super.key});

  @override
  ConsumerState<CartPage> createState() => _CartPageState();
}

class _CartPageState extends ConsumerState<CartPage> {
  @override
  Widget build(BuildContext context) {
    final AsyncValue<User?> authAsync = ref.watch(authStateUserProvider);
    final bool needsSignIn = authAsync.maybeWhen(
      data: (User? user) => user == null,
      orElse: () => false,
    );
    final CartState cart = ref.watch(cartProvider);
    final CartNotifier cartNotifier = ref.read(cartProvider.notifier);
    final int subtotal = cart.subtotal;
    final int discount = cart.discount;
    final int total = subtotal - discount;

    final String storeName =
        cart.isEmpty ? '' : cart.items.first.storeName.trim();

    return Scaffold(
      backgroundColor: AppColors.backgroundCanvas,
      appBar: mndPageAppBar(
        title: 'Your Cart',
        actions: <Widget>[
          if (!cart.isEmpty)
            TextButton(
              onPressed: () async {
                final bool ok = await MndConfirmDialog.show(
                  context,
                  title: 'Clear cart?',
                  message: 'Remove all items from your cart.',
                  icon: Icons.delete_outline_rounded,
                  confirmLabel: 'Clear',
                );
                if (ok) {
                  cartNotifier.clear();
                }
              },
              child: const Text('Clear'),
            ),
        ],
      ),
      body: cart.isEmpty
          ? const _EmptyCartView()
          : Column(
              children: <Widget>[
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    children: <Widget>[
                      if (storeName.isNotEmpty) ...<Widget>[
                        _CartHeroCard(
                          storeName: storeName,
                          itemCount: cart.itemCount,
                          subtotal: subtotal,
                          mode: cart.fulfillmentMode,
                          onModeChanged: cartNotifier.setFulfillmentMode,
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      MndSectionHeader(title: 'Items (${cart.itemCount})'),
                      const SizedBox(height: AppSpacing.sm),
                      ...cart.items.map(
                        (CartItem item) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Dismissible(
                            key: ValueKey<String>(item.lineId),
                            direction: DismissDirection.endToStart,
                            background: _DismissBackground(),
                            onDismissed: (_) => cartNotifier.removeItem(item.lineId),
                            child: _CartItemCard(item: item),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _CartBottomBar(
                  subtotal: subtotal,
                  discount: discount,
                  couponCode: cart.appliedCoupon?.code,
                  total: total,
                  needsSignIn: needsSignIn,
                  onProceedToCheckout: needsSignIn
                      ? () => navigateToSignInForCheckout(ref, context)
                      : () => context.push(AppRoutes.customerCheckout),
                ),
              ],
            ),
    );
  }
}

/// Store identity + fulfillment toggle in a single card (mirrors the
/// checkout page's hero pattern so the cart -> checkout handoff feels
/// like one continuous flow rather than two different apps).
class _CartHeroCard extends StatelessWidget {
  const _CartHeroCard({
    required this.storeName,
    required this.itemCount,
    required this.subtotal,
    required this.mode,
    required this.onModeChanged,
  });

  final String storeName;
  final int itemCount;
  final int subtotal;
  final FulfillmentMode mode;
  final ValueChanged<FulfillmentMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return MndPremiumCard(
      borderRadius: AppColors.cardRadiusSm,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppColors.cardRadiusSm),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.storefront_rounded,
                  color: AppColors.primaryBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      storeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      itemCount == 1
                          ? '1 item · ${MoneyFormat.lkr(subtotal)}'
                          : '$itemCount items · ${MoneyFormat.lkr(subtotal)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _FulfillmentModeSegment(mode: mode, onChanged: onModeChanged),
        ],
      ),
    );
  }
}

class _FulfillmentModeSegment extends StatelessWidget {
  const _FulfillmentModeSegment({
    required this.mode,
    required this.onChanged,
  });

  final FulfillmentMode mode;
  final ValueChanged<FulfillmentMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.homeMutedFill,
        borderRadius: BorderRadius.circular(AppColors.cardRadiusSm),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _SegmentChip(
              label: 'Delivery',
              icon: Icons.delivery_dining_rounded,
              selected: mode == FulfillmentMode.delivery,
              onTap: () => onChanged(FulfillmentMode.delivery),
            ),
          ),
          Expanded(
            child: _SegmentChip(
              label: 'Self pickup',
              icon: Icons.storefront_rounded,
              selected: mode == FulfillmentMode.selfPickup,
              onTap: () => onChanged(FulfillmentMode.selfPickup),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentChip extends StatelessWidget {
  const _SegmentChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primaryBlue : Colors.transparent,
      borderRadius: BorderRadius.circular(AppColors.cardRadiusSm - 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppColors.cardRadiusSm - 2),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : AppColors.textPrimary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DismissBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(AppColors.cardRadiusSm),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
    );
  }
}

class _CartItemCard extends ConsumerWidget {
  const _CartItemCard({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CartNotifier notifier = ref.read(cartProvider.notifier);
    return MndPremiumCard(
      borderRadius: AppColors.cardRadiusSm,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: MndNetworkImage(
              imageUrl: item.imageUrl,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        item.productName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      MoneyFormat.lkr(item.totalPrice),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.brandPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
                if (item.selectedSize.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    'Size: ${item.selectedSize}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
                if (item.extras.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    item.extras.map((e) => e.name).join(', '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: <Widget>[
                    _QtyStepperPill(
                      quantity: item.quantity,
                      onDecrement: () => notifier.updateItemQuantity(
                        lineId: item.lineId,
                        quantity: item.quantity - 1,
                      ),
                      onIncrement: () => notifier.updateItemQuantity(
                        lineId: item.lineId,
                        quantity: item.quantity + 1,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => notifier.removeItem(item.lineId),
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.textSecondary.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyStepperPill extends StatelessWidget {
  const _QtyStepperPill({
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
  });

  final int quantity;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.homeMutedFill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _QtyButton(icon: Icons.remove_rounded, onTap: onDecrement),
          SizedBox(
            width: 28,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          _QtyButton(icon: Icons.add_rounded, onTap: onIncrement),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 18, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _CartBottomBar extends StatelessWidget {
  const _CartBottomBar({
    required this.subtotal,
    required this.discount,
    required this.couponCode,
    required this.total,
    this.needsSignIn = false,
    required this.onProceedToCheckout,
  });

  final int subtotal;
  final int discount;
  final String? couponCode;
  final int total;
  final bool needsSignIn;
  final VoidCallback onProceedToCheckout;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Material(
        color: AppColors.surfaceElevated,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.10),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.homeMutedFill,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                if (discount > 0) ...<Widget>[
                  _PriceRow(
                    label: 'Discount (${couponCode ?? 'COUPON'})',
                    value: '- ${MoneyFormat.lkr(discount)}',
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
                const Divider(height: AppSpacing.lg),
                _PriceRow(
                  label: 'Total',
                  value: MoneyFormat.lkr(total),
                  emphasize: true,
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onProceedToCheckout,
                    child: Text(
                      needsSignIn ? 'Sign in to checkout' : 'Proceed to checkout',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = emphasize
        ? Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.primaryBlue,
            )
        : Theme.of(context).textTheme.bodyMedium;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: style),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(value, style: style, textAlign: TextAlign.end),
        ),
      ],
    );
  }
}

class _EmptyCartView extends StatelessWidget {
  const _EmptyCartView();

  @override
  Widget build(BuildContext context) {
    return MndEmptyState(
      icon: Icons.shopping_cart_outlined,
      title: 'Your cart is empty',
      subtitle: 'Browse nearby stores and add items to get started.',
      actionLabel: 'Order food',
      onAction: () => context.go(AppRoutes.customerFood),
    );
  }
}
