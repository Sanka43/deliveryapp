import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/app/providers/firebase_providers.dart';
import 'package:mnd_delivery_app/features/rides/data/rides_repository.dart';
import 'package:mnd_delivery_app/features/rides/domain/entities/online_ride_rider.dart';
import 'package:mnd_delivery_app/features/rides/domain/entities/ride_place.dart';
import 'package:mnd_delivery_app/features/rides/domain/entities/ride_trip.dart';
import 'package:mnd_delivery_app/features/rides/domain/ride_constants.dart';
import 'package:mnd_delivery_app/features/rides/domain/ride_distance.dart';

/// Max intermediate stops a customer can add between pickup and drop-off.
const int kMaxRideStops = 2;

class RideBookingDraft {
  const RideBookingDraft({
    this.pickup,
    this.dropoff,
    this.stops = const <RidePlace>[],
    this.vehicleType = RideConstants.vehicleBike,
    this.driverNote = '',
    this.contactPhone = '',
    this.quote,
    this.paymentMethod = RideConstants.paymentCash,
  });

  final RidePlace? pickup;
  final RidePlace? dropoff;
  final List<RidePlace> stops;
  final String vehicleType;
  final String driverNote;
  final String contactPhone;
  final RideFareQuote? quote;
  final String paymentMethod;

  bool get canViewVehicles => pickup != null && dropoff != null;

  RideBookingDraft copyWith({
    RidePlace? pickup,
    RidePlace? dropoff,
    List<RidePlace>? stops,
    String? vehicleType,
    String? driverNote,
    String? contactPhone,
    RideFareQuote? quote,
    String? paymentMethod,
    bool clearQuote = false,
  }) {
    return RideBookingDraft(
      pickup: pickup ?? this.pickup,
      dropoff: dropoff ?? this.dropoff,
      stops: stops ?? this.stops,
      vehicleType: vehicleType ?? this.vehicleType,
      driverNote: driverNote ?? this.driverNote,
      contactPhone: contactPhone ?? this.contactPhone,
      quote: clearQuote ? null : (quote ?? this.quote),
      paymentMethod: paymentMethod ?? this.paymentMethod,
    );
  }
}

class RideBookingDraftNotifier extends StateNotifier<RideBookingDraft> {
  RideBookingDraftNotifier() : super(const RideBookingDraft());

  void setPickup(RidePlace place) {
    state = state.copyWith(pickup: place, clearQuote: true);
  }

  void setDropoff(RidePlace place) {
    state = state.copyWith(dropoff: place, clearQuote: true);
  }

  /// Below this, two points are treated as the same place — catches a stop
  /// picked at (or accidentally left at) pickup/dropoff/another stop, which
  /// would otherwise quote a real fare for a zero-distance leg.
  static const double _duplicatePlaceKm = 0.03;

  bool _samePlace(RidePlace a, RidePlace b) {
    return RideDistance.km(a.lat, a.lng, b.lat, b.lng) < _duplicatePlaceKm;
  }

  /// Null on success; an error message if [place] duplicates pickup,
  /// dropoff, or another stop (excluding [ignoreIndex], for an in-place
  /// edit).
  String? _duplicateStopError(RidePlace place, {int? ignoreIndex}) {
    if (state.pickup != null && _samePlace(place, state.pickup!)) {
      return 'This stop is the same as your pickup.';
    }
    if (state.dropoff != null && _samePlace(place, state.dropoff!)) {
      return 'This stop is the same as your drop-off.';
    }
    for (int i = 0; i < state.stops.length; i++) {
      if (i == ignoreIndex) {
        continue;
      }
      if (_samePlace(place, state.stops[i])) {
        return 'You already added this stop.';
      }
    }
    return null;
  }

  /// Returns an error message if [place] was rejected as a duplicate, else
  /// null on success.
  String? addStop(RidePlace place) {
    if (state.stops.length >= kMaxRideStops) {
      return null;
    }
    final String? error = _duplicateStopError(place);
    if (error != null) {
      return error;
    }
    state = state.copyWith(
      stops: <RidePlace>[...state.stops, place],
      clearQuote: true,
    );
    return null;
  }

  /// Returns an error message if [place] was rejected as a duplicate, else
  /// null on success.
  String? updateStopAt(int index, RidePlace place) {
    if (index < 0 || index >= state.stops.length) {
      return null;
    }
    final String? error = _duplicateStopError(place, ignoreIndex: index);
    if (error != null) {
      return error;
    }
    final List<RidePlace> next = List<RidePlace>.of(state.stops);
    next[index] = place;
    state = state.copyWith(stops: next, clearQuote: true);
    return null;
  }

  void removeStopAt(int index) {
    if (index < 0 || index >= state.stops.length) {
      return;
    }
    final List<RidePlace> next = List<RidePlace>.of(state.stops)
      ..removeAt(index);
    state = state.copyWith(stops: next, clearQuote: true);
  }

  void reorderStop(int oldIndex, int newIndex) {
    if (oldIndex == newIndex ||
        oldIndex < 0 ||
        oldIndex >= state.stops.length ||
        newIndex < 0 ||
        newIndex >= state.stops.length) {
      return;
    }
    final List<RidePlace> next = List<RidePlace>.of(state.stops);
    final RidePlace moved = next.removeAt(oldIndex);
    next.insert(newIndex, moved);
    state = state.copyWith(stops: next, clearQuote: true);
  }

  void setVehicleType(String type) {
    if (state.vehicleType == type) {
      return;
    }
    state = state.copyWith(vehicleType: type, clearQuote: true);
  }

  void setDriverNote(String note) {
    state = state.copyWith(driverNote: note);
  }

  void setContactPhone(String phone) {
    state = state.copyWith(contactPhone: phone);
  }

  void setPaymentMethod(String method) {
    state = state.copyWith(paymentMethod: method);
  }

  void setQuote(RideFareQuote quote) {
    if (state.quote?.quoteId == quote.quoteId &&
        state.vehicleType == quote.vehicleType &&
        state.quote?.fareLkr == quote.fareLkr) {
      return;
    }
    state = state.copyWith(quote: quote, vehicleType: quote.vehicleType);
  }

  void reset() {
    state = const RideBookingDraft();
  }
}

final StateNotifierProvider<RideBookingDraftNotifier, RideBookingDraft>
    rideBookingDraftProvider =
    StateNotifierProvider<RideBookingDraftNotifier, RideBookingDraft>(
  (Ref ref) => RideBookingDraftNotifier(),
);

/// Watches auth so the stream rebinds after sign-in / sign-out.
final StreamProvider<RideTrip?> activeRideTripProvider =
    StreamProvider<RideTrip?>((Ref ref) {
  final User? user = resolveAuthUser(ref);
  if (user == null) {
    return Stream<RideTrip?>.value(null);
  }
  return ref
      .watch(ridesRepositoryProvider)
      .watchActiveTrip(customerUid: user.uid);
});

/// A completed-but-unpaid online-pay trip, so the payment prompt is still
/// surfaced after the customer fully closes and reopens the app.
final StreamProvider<RideTrip?> unpaidCompletedRideTripProvider =
    StreamProvider<RideTrip?>((Ref ref) {
  final User? user = resolveAuthUser(ref);
  if (user == null) {
    return Stream<RideTrip?>.value(null);
  }
  return ref
      .watch(ridesRepositoryProvider)
      .watchUnpaidCompletedTrip(customerUid: user.uid);
});

final StreamProviderFamily<RideTrip?, String> rideTripProvider =
    StreamProvider.family<RideTrip?, String>((Ref ref, String tripId) {
  return ref.watch(ridesRepositoryProvider).watchTrip(tripId);
});

/// Online fleet for searching map — keyed by `vehicleType|lat|lng` (3 decimals).
/// Requires a signed-in user (Firestore rules deny anonymous reads).
final StreamProviderFamily<List<OnlineRideRider>, String>
    onlineRidersNearPickupProvider =
    StreamProvider.family<List<OnlineRideRider>, String>((Ref ref, String key) {
  final User? user = resolveAuthUser(ref);
  if (user == null) {
    return Stream<List<OnlineRideRider>>.value(const <OnlineRideRider>[]);
  }
  final List<String> parts = key.split('|');
  if (parts.length < 3) {
    return Stream<List<OnlineRideRider>>.value(const <OnlineRideRider>[]);
  }
  final String vehicleType = parts[0];
  final double? lat = double.tryParse(parts[1]);
  final double? lng = double.tryParse(parts[2]);
  if (lat == null || lng == null || vehicleType.isEmpty) {
    return Stream<List<OnlineRideRider>>.value(const <OnlineRideRider>[]);
  }
  return ref.watch(ridesRepositoryProvider).watchOnlineRidersForVehicle(
        vehicleType: vehicleType,
        nearLat: lat,
        nearLng: lng,
      );
});

String onlineRidersQueryKey({
  required String vehicleType,
  required double lat,
  required double lng,
}) {
  return '${vehicleType.trim().toLowerCase()}|'
      '${lat.toStringAsFixed(3)}|${lng.toStringAsFixed(3)}';
}

/// Watches auth so the stream rebinds after sign-in / sign-out.
final StreamProvider<List<RideTrip>> myRideTripsProvider =
    StreamProvider<List<RideTrip>>((Ref ref) {
  final User? user = resolveAuthUser(ref);
  if (user == null) {
    return Stream<List<RideTrip>>.value(const <RideTrip>[]);
  }
  return ref
      .watch(ridesRepositoryProvider)
      .watchMyTrips(customerUid: user.uid);
});

final StreamProvider<RideFareConfig> rideFareConfigProvider =
    StreamProvider<RideFareConfig>((Ref ref) {
  return ref.watch(ridesRepositoryProvider).watchRideFareConfig();
});
