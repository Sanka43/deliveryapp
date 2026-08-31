import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/features/cart/domain/delivery_pricing.dart';
import 'package:mnd_delivery_app/features/cart/domain/platform_fee_config.dart';
import 'package:mnd_delivery_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:mnd_delivery_app/features/cart/presentation/providers/platform_fee_config_provider.dart';
import 'package:mnd_delivery_app/features/cart/presentation/providers/store_location_provider.dart';
import 'package:mnd_delivery_app/features/rides/data/ride_directions_service.dart';

typedef _RoutePoints = ({
  double originLat,
  double originLng,
  double dropLat,
  double dropLng,
});

/// Real road distance (km) between the store and drop-off, matching what
/// Google Maps shows — unlike [DeliveryPricing.distanceKm], which is a
/// straight-line estimate. Null while loading or if the route lookup fails,
/// so callers fall back to the straight-line distance.
final AutoDisposeFutureProviderFamily<double?, _RoutePoints>
    _drivingDistanceKmProvider =
    FutureProvider.autoDispose.family<double?, _RoutePoints>(
  (Ref ref, _RoutePoints p) async {
    final RideDrivingRoute? route =
        await ref.read(rideDirectionsServiceProvider).fetchDrivingRoute(
              originLat: p.originLat,
              originLng: p.originLng,
              destLat: p.dropLat,
              destLng: p.dropLng,
            );
    return route?.distanceKm;
  },
);

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

DeliveryFeeQuote _estimatedFallback({required bool hasPin}) {
  return DeliveryFeeQuote(
    feeLkr: DeliveryPricing.fallbackFlatLkr,
    distanceKm: null,
    isDistanceBased: false,
    detail: hasPin
        ? 'Estimated delivery fee'
        : 'Estimated · pin on map for exact fee',
  );
}

final Provider<DeliveryFeeQuote> deliveryFeeQuoteProvider =
    Provider<DeliveryFeeQuote>((Ref ref) {
  final CartState cart = ref.watch(cartProvider);
  if (cart.isEmpty) {
    return const DeliveryFeeQuote(
      feeLkr: 0,
      distanceKm: null,
      isDistanceBased: false,
      detail: null,
    );
  }

  if (cart.isSelfPickup) {
    return const DeliveryFeeQuote(
      feeLkr: 0,
      distanceKm: null,
      isDistanceBased: false,
      detail: 'Self pickup — Free',
    );
  }

  final bool hasPin =
      cart.dropoffLatitude != null && cart.dropoffLongitude != null;
  final String storeId = cart.items.first.storeId;
  final AsyncValue<StoreLocation?> originAsync =
      ref.watch(storeLocationByStoreIdProvider(storeId));

  return originAsync.when(
    data: (StoreLocation? origin) {
      final double? dropLat = cart.dropoffLatitude;
      final double? dropLng = cart.dropoffLongitude;
      if (origin == null || dropLat == null || dropLng == null) {
        return _estimatedFallback(hasPin: hasPin);
      }
      final double straightKm = DeliveryPricing.distanceKm(
        origin.latitude,
        origin.longitude,
        dropLat,
        dropLng,
      );
      final AsyncValue<double?> drivingAsync = ref.watch(
        _drivingDistanceKmProvider((
          originLat: origin.latitude,
          originLng: origin.longitude,
          dropLat: dropLat,
          dropLng: dropLng,
        )),
      );
      final double km = drivingAsync.asData?.value ?? straightKm;
      final PlatformFeeConfig feeConfig =
          ref.watch(platformFeeConfigProvider).valueOrNull ??
              const PlatformFeeConfig.defaults();
      final int fee = DeliveryPricing.feeLkrForDistanceKm(
        km,
        minimumFeeLkrOverride: feeConfig.minimumFeeLkr,
        perKmAfterIncludedLkrOverride: feeConfig.perKmAfterIncludedLkr,
      );
      return DeliveryFeeQuote(
        feeLkr: fee,
        distanceKm: km,
        isDistanceBased: true,
        detail: '${km.toStringAsFixed(1)} km from store',
      );
    },
    loading: () => _estimatedFallback(hasPin: hasPin),
    error: (_, __) => _estimatedFallback(hasPin: hasPin),
  );
});
