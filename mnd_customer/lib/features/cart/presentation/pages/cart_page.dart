import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/app/providers/firebase_providers.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/widgets/sign_in_required_prompt.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_brand_watermark.dart';
import 'package:mnd_delivery_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:mnd_delivery_app/features/cart/presentation/providers/delivery_fee_quote_provider.dart';

class CartPage extends ConsumerStatefulWidget {
  const CartPage({super.key});

  @override
  ConsumerState<CartPage> createState() => _CartPageState();
}

class _CartPageState extends ConsumerState<CartPage> {
  final TextEditingController _couponController = TextEditingController();
  final TextEditingController _deliveryNoteController = TextEditingController();
  final TextEditingController _specialInstructionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final CartState cart = ref.read(cartProvider);
    _deliveryNoteController.text = cart.deliveryNote;
    _specialInstructionController.text = cart.specialInstructions;
  }

  @override
  void dispose() {
    _couponController.dispose();
    _deliveryNoteController.dispose();
    _specialInstructionController.dispose();
    super.dispose();
  }

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
    final DeliveryFeeQuote deliveryQuote = ref.watch(deliveryFeeQuoteProvider);
    final int deliveryFee = deliveryQuote.feeLkr;
    final int total = subtotal - discount + deliveryFee;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Cart'),
        actions: <Widget>[
          if (!cart.isEmpty)
            TextButton(
              onPressed: cartNotifier.clear,
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
                    padding: const EdgeInsets.all(AppSpacing.md),
                    children: <Widget>[
                      Text(
                        'Items (${cart.itemCount})',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ...cart.items.map(
                        (CartItem item) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _CartItemCard(item: item),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Order options',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _CouponCard(
                        controller: _couponController,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _DeliveryInstructionCard(
                        deliveryNoteController: _deliveryNoteController,
                        specialInstructionController: _specialInstructionController,
                      ),
                    ],
                  ),
                ),
                _CartTotals(
                  subtotal: subtotal,
                  discount: discount,
                  couponCode: cart.appliedCoupon?.code,
                  deliveryFee: deliveryFee,
                  deliveryDetail: deliveryQuote.detail,
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

class _CouponCard extends ConsumerWidget {
  const _CouponCard({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CartState cart = ref.watch(cartProvider);
    final CartNotifier cartNotifier = ref.read(cartProvider.notifier);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Coupon Code',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    hintText: 'Enter coupon (e.g. MND10)',
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              FilledButton(
                onPressed: () {
                  final String code = controller.text.trim();
                  if (code.isEmpty) {
                    return;
                  }
                  final bool success = cartNotifier.applyCouponCode(code);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success ? 'Coupon applied: ${code.toUpperCase()}' : 'Invalid coupon code',
                      ),
                    ),
                  );
                },
                child: const Text('Apply'),
              ),
            ],
          ),
          if (cart.appliedCoupon != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: <Widget>[
                Text(
                  'Applied: ${cart.appliedCoupon!.code}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: cartNotifier.removeCoupon,
                  child: const Text('Remove'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CartItemCard extends ConsumerWidget {
  const _CartItemCard({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CartNotifier notifier = ref.read(cartProvider.notifier);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              item.imageUrl,
              width: 74,
              height: 74,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 74,
                height: 74,
                color: AppColors.primaryBlue.withValues(alpha: 0.08),
                alignment: Alignment.center,
                padding: const EdgeInsets.all(4),
                child: const FittedBox(
                  fit: BoxFit.contain,
                  child: MndBrandWatermark(
                    mndFontSize: 28,
                    subtitleFontSize: 8,
                    mndOpacity: 0.24,
                    subtitleOpacity: 0.18,
                  ),
                ),
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
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  'Size: ${item.selectedSize}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.black54,
                      ),
                ),
                if (item.extras.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    'Extras: ${item.extras.map((e) => e.name).join(', ')}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.black54,
                        ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _formatLkr(item.totalPrice),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          Column(
            children: <Widget>[
              IconButton(
                onPressed: () {
                  notifier.removeItem(item.lineId);
                },
                icon: const Icon(Icons.delete_outline_rounded),
              ),
              Row(
                children: <Widget>[
                  IconButton(
                    onPressed: () {
                      notifier.updateItemQuantity(
                        lineId: item.lineId,
                        quantity: item.quantity - 1,
                      );
                    },
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text('${item.quantity}'),
                  IconButton(
                    onPressed: () {
                      notifier.updateItemQuantity(
                        lineId: item.lineId,
                        quantity: item.quantity + 1,
                      );
                    },
                    icon: const Icon(Icons.add_circle_outline),
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

class _DeliveryInstructionCard extends ConsumerWidget {
  const _DeliveryInstructionCard({
    required this.deliveryNoteController,
    required this.specialInstructionController,
  });

  final TextEditingController deliveryNoteController;
  final TextEditingController specialInstructionController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CartNotifier cartNotifier = ref.read(cartProvider.notifier);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Delivery Note',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: deliveryNoteController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: 'e.g. Leave at front door',
            ),
            onChanged: cartNotifier.setDeliveryNote,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Special Instructions',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: specialInstructionController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'e.g. No onions, call before arrival',
            ),
            onChanged: cartNotifier.setSpecialInstructions,
          ),
        ],
      ),
    );
  }
}

class _CartTotals extends StatelessWidget {
  const _CartTotals({
    required this.subtotal,
    required this.discount,
    required this.couponCode,
    required this.deliveryFee,
    this.deliveryDetail,
    required this.total,
    this.needsSignIn = false,
    required this.onProceedToCheckout,
  });

  final int subtotal;
  final int discount;
  final String? couponCode;
  final int deliveryFee;
  final String? deliveryDetail;
  final int total;
  final bool needsSignIn;
  final VoidCallback onProceedToCheckout;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        children: <Widget>[
          _PriceRow(label: 'Subtotal', value: _formatLkr(subtotal)),
          const SizedBox(height: AppSpacing.xs),
          if (discount > 0) ...<Widget>[
            _PriceRow(
              label: 'Discount (${couponCode ?? 'COUPON'})',
              value: '- ${_formatLkr(discount)}',
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          _PriceRow(
            label: 'Delivery',
            value: _formatLkr(deliveryFee),
            detail: deliveryDetail,
          ),
          const Divider(height: AppSpacing.lg),
          _PriceRow(
            label: 'Total',
            value: _formatLkr(total),
            emphasize: true,
          ),
          const SizedBox(height: AppSpacing.md),
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
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.value,
    this.emphasize = false,
    this.detail,
  });

  final String label;
  final String value;
  final bool emphasize;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = emphasize
        ? Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)
        : Theme.of(context).textTheme.bodyMedium;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: style),
        const Spacer(),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(value, style: style, textAlign: TextAlign.end),
              if (detail != null && detail!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    detail!,
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.black54,
                        ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyCartView extends StatelessWidget {
  const _EmptyCartView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.shopping_cart_outlined,
              size: 56,
              color: Colors.black.withValues(alpha: 0.4),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Your cart is empty',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Add some items from store to continue.',
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
}

String _formatLkr(int amount) => 'LKR $amount';
