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
import 'package:mnd_delivery_app/features/customer/presentation/providers/customer_search_provider.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/home/home_navigation_helpers.dart';
import 'package:mnd_delivery_app/l10n/generated/app_localizations.dart';

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
    final bool exceedsMaxOrderValue = cart.exceedsMaxOrderValue;

    final String storeName =
        cart.isEmpty ? '' : cart.items.first.storeName.trim();

    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.backgroundCanvas,
      appBar: mndPageAppBar(
        title: l10n.cartTitle,
        actions: <Widget>[
          if (!cart.isEmpty)
            TextButton(
              onPressed: () async {
                final bool ok = await MndConfirmDialog.show(
                  context,
                  title: l10n.cartClearTitle,
                  message: l10n.cartClearMessage,
                  icon: Icons.delete_outline_rounded,
                  confirmLabel: l10n.actionClear,
                );
                if (ok) {
                  cartNotifier.clear();
                }
              },
              child: Text(l10n.actionClear),
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
                          storeId: cart.items.first.storeId,
                          storeName: storeName,
                          itemCount: cart.itemCount,
                          subtotal: subtotal,
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      if (exceedsMaxOrderValue) ...<Widget>[
                        _MaxOrderValueBanner(
                          message: l10n.cartMaxOrderValueExceeded(
                            MoneyFormat.lkr(kMaxOrderValueLkr),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      MndSectionHeader(
                        title: l10n.cartItemsHeader(cart.itemCount),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ...cart.items.map(
                        (CartItem item) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Dismissible(
                            key: ValueKey<String>(item.lineId),
                            direction: DismissDirection.endToStart,
                            background: _DismissBackground(),
                            onDismissed: (_) =>
                                cartNotifier.removeItem(item.lineId),
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
                  disabled: exceedsMaxOrderValue,
                  onProceedToCheckout: exceedsMaxOrderValue
                      ? null
                      : needsSignIn
                          ? () => navigateToSignInForCheckout(ref, context)
                          : () => context.push(AppRoutes.customerCheckout),
                ),
              ],
            ),
    );
  }
}

/// Store identity card — live logo and open/closed cue from the vendor doc,
/// tappable to reopen the store's menu. The delivery/pickup choice now lives
/// only on checkout (it was duplicated here, one tap apart from the same
/// control there, and out of sync with the Order type section that depends
/// on it).
class _CartHeroCard extends ConsumerWidget {
  const _CartHeroCard({
    required this.storeId,
    required this.storeName,
    required this.itemCount,
    required this.subtotal,
  });

  final String storeId;
  final String storeName;
  final int itemCount;
  final int subtotal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String trimmedId = storeId.trim();
    final SearchStore? live = trimmedId.isEmpty
        ? null
        : ref.watch(vendorDocStreamProvider(trimmedId)).asData?.value;
    final String imageUrl = live?.imageUrl.trim() ?? '';
    final bool isOpen = live?.isOpen ?? true;

    return MndPremiumCard(
      borderRadius: AppColors.cardRadiusSm,
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: live == null ? null : () => openStoreDetails(context, live),
      child: Row(
        children: <Widget>[
          Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: imageUrl.isEmpty
                    ? const _StoreAvatarFallback()
                    : MndNetworkImage(
                        imageUrl: imageUrl,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        errorChild: const _StoreAvatarFallback(),
                      ),
              ),
              if (!isOpen)
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppColors.surfaceElevated,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      'Closed',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontSize: 9,
                            height: 1.0,
                          ),
                    ),
                  ),
                ),
            ],
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
                  AppLocalizations.of(context).cartItemCountSummary(
                      itemCount, MoneyFormat.lkr(subtotal)),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          if (live != null)
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary.withValues(alpha: 0.6),
            ),
        ],
      ),
    );
  }
}

class _StoreAvatarFallback extends StatelessWidget {
  const _StoreAvatarFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      color: AppColors.primaryBlue.withValues(alpha: 0.10),
      alignment: Alignment.center,
      child: const Icon(
        Icons.storefront_rounded,
        color: AppColors.primaryBlue,
        size: 24,
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
                    AppLocalizations.of(context)
                        .cartItemSizeLabel(item.selectedSize),
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
    this.disabled = false,
    required this.onProceedToCheckout,
  });

  final int subtotal;
  final int discount;
  final String? couponCode;
  final int total;
  final bool needsSignIn;
  final bool disabled;
  final VoidCallback? onProceedToCheckout;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
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
                    label: l10n.cartDiscountLabel(
                      couponCode ?? l10n.cartGenericCouponLabel,
                    ),
                    value: '- ${MoneyFormat.lkr(discount)}',
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
                const Divider(height: AppSpacing.lg),
                _PriceRow(
                  label: l10n.cartTotalLabel,
                  value: MoneyFormat.lkr(total),
                  emphasize: true,
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const ValueKey<String>('proceedToCheckoutButton'),
                    onPressed: onProceedToCheckout,
                    child: Text(
                      needsSignIn
                          ? l10n.cartSignInToCheckout
                          : l10n.cartProceedToCheckout,
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

class _MaxOrderValueBanner extends StatelessWidget {
  const _MaxOrderValueBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppColors.cardRadiusSm),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 20),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCartView extends StatelessWidget {
  const _EmptyCartView();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return MndEmptyState(
      icon: Icons.shopping_cart_outlined,
      title: l10n.cartEmptyTitle,
      subtitle: l10n.cartEmptySubtitle,
      actionLabel: l10n.homeHeroOrderFood,
      onAction: () => context.go(AppRoutes.customerFood),
    );
  }
}
