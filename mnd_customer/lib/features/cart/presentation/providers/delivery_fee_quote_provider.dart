import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/features/cart/domain/delivery_pricing.dart';
import 'package:mnd_delivery_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:mnd_delivery_app/features/cart/presentation/providers/store_location_provider.dart';

/// Resolved delivery charge and optional distance context for UI.
class DeliveryFeeQuote {
  const DeliveryFeeQuote({
    required this.feeLkr,
    this.distanceKm,
    required this.isDistanceBased,
    this.detail,
  });

  final int feeLkr;
  final double? distanceKm;
  final bool isDistanceBased;

  /// Short line for summaries (e.g. under "Delivery").
  final String? detail;
}

final Provider<DeliveryFeeQuote> deliveryFeeQuoteProvider = Provider<DeliveryFeeQuote>((Ref ref) {
  final CartState cart = ref.watch(cartProvider);
  if (cart.isEmpty) {
    return const DeliveryFeeQuote(
      feeLkr: 0,
      distanceKm: null,
      isDistanceBased: false,
      detail: null,
    );
  }

  final String storeId = cart.items.first.storeId;
  final AsyncValue<StoreLocation?> originAsync =
      ref.watch(storeLocationByStoreIdProvider(storeId));

  return originAsync.maybeWhen(
    data: (StoreLocation? origin) {
      final double? dropLat = cart.dropoffLatitude;
      final double? dropLng = cart.dropoffLongitude;
      if (origin == null || dropLat == null || dropLng == null) {
        return DeliveryFeeQuote(
          feeLkr: DeliveryPricing.fallbackFlatLkr,
          distanceKm: null,
          isDistanceBased: false,
          detail: origin == null
              ? 'Flat rate — add store coordinates in Firestore'
              : 'Flat rate — pick on map at checkout',
        );
      }
      final double km = DeliveryPricing.distanceKm(
        origin.latitude,
        origin.longitude,
        dropLat,
        dropLng,
      );
      final int fee = DeliveryPricing.feeLkrForDistanceKm(km);
      return DeliveryFeeQuote(
        feeLkr: fee,
        distanceKm: km,
        isDistanceBased: true,
        detail: '${km.toStringAsFixed(1)} km from store',
      );
    },
    orElse: () => const DeliveryFeeQuote(
      feeLkr: DeliveryPricing.fallbackFlatLkr,
      distanceKm: null,
      isDistanceBased: false,
      detail: null,
    ),
  );
});
