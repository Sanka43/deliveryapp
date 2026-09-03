import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/features/rides/data/rides_repository.dart';
import 'package:mnd_delivery_app/features/rides/domain/entities/ride_place.dart';
import 'package:mnd_delivery_app/features/rides/presentation/providers/rides_providers.dart';

/// Cache key for batch fare quotes (pickup → [stops] → dropoff).
class RideFareQuotesKey {
  const RideFareQuotesKey(
    this.origin,
    this.destination, [
    this.stops = const <RidePlace>[],
  ]);

  final RidePlace origin;
  final RidePlace destination;
  final List<RidePlace> stops;

  @override
  bool operator ==(Object other) {
    if (other is! RideFareQuotesKey ||
        other.origin.lat != origin.lat ||
        other.origin.lng != origin.lng ||
        other.destination.lat != destination.lat ||
        other.destination.lng != destination.lng ||
        other.stops.length != stops.length) {
      return false;
    }
    for (int i = 0; i < stops.length; i++) {
      if (other.stops[i].lat != stops[i].lat ||
          other.stops[i].lng != stops[i].lng) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        origin.lat,
        origin.lng,
        destination.lat,
        destination.lng,
        Object.hashAll(
          stops.expand((RidePlace s) => <double>[s.lat, s.lng]),
        ),
      );
}

RideFareQuotesKey? draftFareQuotesKey(RideBookingDraft draft) {
  final RidePlace? pickup = draft.pickup;
  final RidePlace? dropoff = draft.dropoff;
  if (pickup == null || dropoff == null) {
    return null;
  }
  return RideFareQuotesKey(pickup, dropoff, draft.stops);
}

/// Server fare quotes for a pickup/dropoff pair.
/// Not autoDispose so booking → confirm navigation keeps an in-flight prefetch.
final FutureProviderFamily<List<RideFareQuote>, RideFareQuotesKey>
    rideFareQuotesProvider =
    FutureProvider.family<List<RideFareQuote>, RideFareQuotesKey>(
  (Ref ref, RideFareQuotesKey key) {
    return ref.read(ridesRepositoryProvider).quoteAllFares(
          pickup: key.origin,
          dropoff: key.destination,
          stops: key.stops,
        );
  },
);

/// Warm / watch quotes for the current draft (no-op if incomplete).
final Provider<AsyncValue<List<RideFareQuote>>?> draftRideFareQuotesProvider =
    Provider<AsyncValue<List<RideFareQuote>>?>((Ref ref) {
  final RideFareQuotesKey? key =
      draftFareQuotesKey(ref.watch(rideBookingDraftProvider));
  if (key == null) {
    return null;
  }
  return ref.watch(rideFareQuotesProvider(key));
});
