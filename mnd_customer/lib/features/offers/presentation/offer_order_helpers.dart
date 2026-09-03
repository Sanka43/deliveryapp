import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/utils/money_format.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_snackbar.dart';
import 'package:mnd_delivery_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/home/home_navigation_helpers.dart';
import 'package:mnd_delivery_app/features/offers/domain/customer_offer.dart';

/// Adds an offer as a cart line and opens cart (or prompts to clear other-store cart).
Future<void> orderCustomerOffer(
  BuildContext context,
  WidgetRef ref,
  CustomerOffer offer,
) async {
  if (!offer.isLive) {
    showMndSnackBar(context, 'This offer has ended.', variant: MndSnackBarVariant.warning);
    return;
  }

  if (!isStoreOpenInCatalog(ref, offer.storeId)) {
    if (context.mounted) {
      showShopClosedSnackBar(context);
    }
    return;
  }

  final CartItem item = CartItem(
    productKey: 'offer_${offer.id}',
    productName: offer.title,
    storeId: offer.storeId,
    storeName: offer.storeName,
    imageUrl: offer.imageUrl,
    selectedSize: 'Offer',
    quantity: 1,
    basePrice: offer.priceLkr,
    sizePriceDelta: 0,
  );

  final bool added = ref.read(cartProvider.notifier).addItem(item);
  if (!added) {
    if (!context.mounted) {
      return;
    }
    showMndSnackBar(
      context,
      'Cart has items from another store.',
      variant: MndSnackBarVariant.warning,
      actionLabel: 'Clear & order',
      onAction: () {
        if (!isStoreOpenInCatalog(ref, offer.storeId)) {
          showShopClosedSnackBar(context);
          return;
        }
        ref.read(cartProvider.notifier).clear();
        ref.read(cartProvider.notifier).addItem(item);
        if (context.mounted) {
          context.push(AppRoutes.customerCart);
        }
      },
    );
    return;
  }

  if (!context.mounted) {
    return;
  }
  context.push(AppRoutes.customerCart);
}

String formatOfferEndsLabel(DateTime endsAt) {
  final Duration left = endsAt.difference(DateTime.now());
  if (left.isNegative) {
    return 'Ended';
  }
  if (left.inDays >= 1) {
    return 'Ends in ${left.inDays}d';
  }
  if (left.inHours >= 1) {
    return 'Ends in ${left.inHours}h';
  }
  final int mins = left.inMinutes.clamp(1, 59);
  return 'Ends in ${mins}m';
}

/// Live countdown label: `2d 05:12:09` or `05:12:09`.
String formatOfferCountdown(DateTime endsAt, {DateTime? now}) {
  Duration left = endsAt.difference(now ?? DateTime.now());
  if (left.isNegative) {
    return '00:00:00';
  }
  final int days = left.inDays;
  final int hours = left.inHours.remainder(24);
  final int minutes = left.inMinutes.remainder(60);
  final int seconds = left.inSeconds.remainder(60);
  String two(int n) => n.toString().padLeft(2, '0');
  final String hms = '${two(hours)}:${two(minutes)}:${two(seconds)}';
  if (days > 0) {
    return '${days}d $hms';
  }
  return hms;
}

String formatOfferPrice(int priceLkr) =>
    MoneyFormat.lkr(priceLkr, showDecimals: false);
