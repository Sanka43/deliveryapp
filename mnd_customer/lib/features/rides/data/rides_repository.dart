import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/app/providers/firebase_providers.dart';
import 'package:mnd_delivery_app/core/constants/firebase_collections.dart';
import 'package:mnd_delivery_app/core/utils/user_facing_error.dart';
import 'package:mnd_delivery_app/features/rides/domain/entities/online_ride_rider.dart';
import 'package:mnd_delivery_app/features/rides/domain/entities/ride_place.dart';
import 'package:mnd_delivery_app/features/rides/domain/entities/ride_trip.dart';
import 'package:mnd_delivery_app/features/rides/domain/ride_constants.dart';
import 'package:mnd_delivery_app/features/rides/domain/ride_distance.dart';

final Provider<RidesRepository> ridesRepositoryProvider =
    Provider<RidesRepository>((Ref ref) {
  return RidesRepository(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
    functions: FirebaseFunctions.instanceFor(region: 'asia-south1'),
  );
});

class PayHereCheckout {
  const PayHereCheckout({
    required this.tripId,
    required this.checkoutPageUrl,
  });

  final String tripId;
  final String checkoutPageUrl;

  factory PayHereCheckout.fromCallable(Map<String, dynamic> data) {
    return PayHereCheckout(
      tripId: (data['tripId'] as String?)?.trim() ?? '',
      checkoutPageUrl: (data['checkoutPageUrl'] as String?)?.trim() ?? '',
    );
  }
}

class RidesRepository {
  RidesRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    required FirebaseFunctions functions,
  })  : _firestore = firestore,
        _auth = auth,
        _functions = functions;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _trips =>
      _firestore.collection(FirebaseCollections.trips);

  Future<RideFareQuote> quoteFare({
    required RidePlace pickup,
    required RidePlace dropoff,
    required String vehicleType,
    List<RidePlace> stops = const <RidePlace>[],
  }) async {
    final HttpsCallableResult<dynamic> result =
        await _functions.httpsCallable('quoteRideFare').call(<String, dynamic>{
      'pickup': pickup.toMap(),
      'dropoff': dropoff.toMap(),
      'vehicleType': vehicleType,
      if (stops.isNotEmpty)
        'stops': stops.map((RidePlace s) => s.toMap()).toList(),
    });
    final Map<String, dynamic> data =
        Map<String, dynamic>.from(result.data as Map);
    return RideFareQuote.fromCallable(data);
  }

  /// Prefer one batch callable; fall back to parallel single quotes.
  Future<List<RideFareQuote>> quoteAllFares({
    required RidePlace pickup,
    required RidePlace dropoff,
    List<RidePlace> stops = const <RidePlace>[],
  }) async {
    try {
      final HttpsCallableResult<dynamic> result = await _functions
          .httpsCallable('quoteRideFares')
          .call(<String, dynamic>{
        'pickup': pickup.toMap(),
        'dropoff': dropoff.toMap(),
        if (stops.isNotEmpty)
          'stops': stops.map((RidePlace s) => s.toMap()).toList(),
      });
      final Map<String, dynamic> data =
          Map<String, dynamic>.from(result.data as Map);
      final List<dynamic> raw =
          List<dynamic>.from(data['quotes'] as List? ?? <dynamic>[]);
      if (raw.isNotEmpty) {
        return raw
            .map(
              (dynamic e) => RideFareQuote.fromCallable(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();
      }
    } catch (e) {
      // Older backends without quoteRideFares — parallel singles below.
      assert(() {
        debugPrint('quoteRideFares failed, falling back to quoteRideFare×3: $e');
        return true;
      }());
    }

    final List<RideFareQuote> quotes = await Future.wait(
      RideVehicleType.values.map(
        (RideVehicleType type) => quoteFare(
          pickup: pickup,
          dropoff: dropoff,
          vehicleType: type.firestoreValue,
          stops: stops,
        ),
      ),
    );
    return quotes;
  }

  /// Creates a trip and starts driver search immediately, for cash or
  /// PayHere alike. PayHere trips are settled after the ride ends — see
  /// [createPayHereCheckoutForTrip].
  Future<String> confirmCashRide({
    required String quoteId,
    required String contactPhone,
    String driverNote = '',
    String paymentMethod = RideConstants.paymentCash,
  }) async {
    final HttpsCallableResult<dynamic> result = await _functions
        .httpsCallable('confirmCashRide')
        .call(<String, dynamic>{
      'quoteId': quoteId,
      'contactPhone': contactPhone,
      'driverNote': driverNote,
      'paymentMethod': paymentMethod,
    });
    final Map<String, dynamic> data =
        Map<String, dynamic>.from(result.data as Map);
    return (data['tripId'] as String?)?.trim() ?? '';
  }

  /// Pay online for a trip that already completed with an outstanding
  /// PayHere balance (i.e. online pay selected at booking, charged at the
  /// end of the ride).
  Future<PayHereCheckout> createPayHereCheckoutForTrip({
    required String tripId,
    String firstName = 'Customer',
    String lastName = 'MND',
    String email = '',
  }) async {
    final HttpsCallableResult<dynamic> result = await _functions
        .httpsCallable('createPayHereCheckoutForTrip')
        .call(<String, dynamic>{
      'tripId': tripId,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
    });
    final Map<String, dynamic> data =
        Map<String, dynamic>.from(result.data as Map);
    return PayHereCheckout.fromCallable(data);
  }

  Future<PayHereCheckout> createPayHereCheckout({
    required String quoteId,
    required String contactPhone,
    String driverNote = '',
    String firstName = 'Customer',
    String lastName = 'MND',
    String email = '',
  }) async {
    final HttpsCallableResult<dynamic> result = await _functions
        .httpsCallable('createPayHereCheckout')
        .call(<String, dynamic>{
      'quoteId': quoteId,
      'contactPhone': contactPhone,
      'driverNote': driverNote,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
    });
    final Map<String, dynamic> data =
        Map<String, dynamic>.from(result.data as Map);
    return PayHereCheckout.fromCallable(data);
  }

  Stream<RideTrip?> watchTrip(String tripId) {
    final String id = tripId.trim();
    if (id.isEmpty) {
      return Stream<RideTrip?>.value(null);
    }
    return _trips.doc(id).snapshots().map(
      (DocumentSnapshot<Map<String, dynamic>> snap) {
        if (!snap.exists || snap.data() == null) {
          return null;
        }
        return RideTrip.fromDoc(snap.id, snap.data()!);
      },
    );
  }

  Stream<List<RideTrip>> watchMyTrips({
    required String customerUid,
    int limit = 40,
  }) {
    if (customerUid.isEmpty) {
      return Stream<List<RideTrip>>.value(const <RideTrip>[]);
    }
    return _trips
        .where('customerId', isEqualTo: customerUid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                    RideTrip.fromDoc(d.id, d.data()),
              )
              .toList(growable: false),
        );
  }

  Stream<RideTrip?> watchActiveTrip({required String customerUid}) {
    if (customerUid.isEmpty) {
      return Stream<RideTrip?>.value(null);
    }
    return _trips
        .where('customerId', isEqualTo: customerUid)
        .where('status', whereIn: RideConstants.activeStatuses)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snap) {
      if (snap.docs.isEmpty) {
        return null;
      }
      final QueryDocumentSnapshot<Map<String, dynamic>> d = snap.docs.first;
      return RideTrip.fromDoc(d.id, d.data());
    });
  }

  /// A completed trip the customer paid for online but hasn't paid yet —
  /// surfaces the "Pay now" prompt even after the app was closed/backgrounded
  /// past the moment the trip finished.
  Stream<RideTrip?> watchUnpaidCompletedTrip({required String customerUid}) {
    if (customerUid.isEmpty) {
      return Stream<RideTrip?>.value(null);
    }
    return _trips
        .where('customerId', isEqualTo: customerUid)
        .where('status', isEqualTo: RideConstants.statusCompleted)
        .where('paymentMethod', isEqualTo: RideConstants.paymentPayHere)
        .where('paymentStatus', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snap) {
      if (snap.docs.isEmpty) {
        return null;
      }
      final QueryDocumentSnapshot<Map<String, dynamic>> d = snap.docs.first;
      return RideTrip.fromDoc(d.id, d.data());
    });
  }

  Future<String?> cancelSearchingTrip(String tripId, {String? reason}) async {
    final User? u = _auth.currentUser;
    if (u == null) {
      return 'Not signed in.';
    }
    try {
      await _trips.doc(tripId).update(<String, dynamic>{
        'status': RideConstants.statusCancelled,
        'openForRiders': false,
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelReason': reason ?? 'customer_cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) {
      return userFacingError(e, fallback: 'Could not cancel trip.');
    }
  }

  /// Online riders for [vehicleType] (`bike` / `wheel` / `car`), near [nearLat]/[nearLng].
  /// Uses a latitude band query so we do not snapshot every online rider nationwide.
  Stream<List<OnlineRideRider>> watchOnlineRidersForVehicle({
    required String vehicleType,
    required double nearLat,
    required double nearLng,
    double radiusKm = 12,
    int maxResults = 30,
  }) {
    final String type = vehicleType.trim().toLowerCase();
    if (type.isEmpty) {
      return Stream<List<OnlineRideRider>>.value(const <OnlineRideRider>[]);
    }
    // ~1° latitude ≈ 111 km; pad slightly so edges stay inside the band.
    final double latDelta = (radiusKm / 111.32) * 1.15;
    final double minLat = nearLat - latDelta;
    final double maxLat = nearLat + latDelta;

    return _firestore
        .collection(FirebaseCollections.riderLocations)
        .where('online', isEqualTo: true)
        .where('vehicleType', isEqualTo: type)
        .where('latitude', isGreaterThanOrEqualTo: minLat)
        .where('latitude', isLessThanOrEqualTo: maxLat)
        .limit(80)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snap) {
      final List<({OnlineRideRider rider, double km})> scored =
          <({OnlineRideRider rider, double km})>[];
      for (final QueryDocumentSnapshot<Map<String, dynamic>> d in snap.docs) {
        final OnlineRideRider? rider = OnlineRideRider.fromDoc(d.id, d.data());
        if (rider == null) {
          continue;
        }
        final double km = RideDistance.km(
          nearLat,
          nearLng,
          rider.latitude,
          rider.longitude,
        );
        if (km > radiusKm) {
          continue;
        }
        scored.add((rider: rider, km: km));
      }
      scored.sort(
        (({OnlineRideRider rider, double km}) a,
                ({OnlineRideRider rider, double km}) b) =>
            a.km.compareTo(b.km),
      );
      return scored
          .take(maxResults)
          .map((({OnlineRideRider rider, double km}) e) => e.rider)
          .toList(growable: false);
    });
  }

  /// Submit a 1–5 star rider rating for a completed ride (one rating per trip).
  Future<RideRatingResult> submitRiderRatingForTrip({
    required String tripId,
    required int stars,
    String? comment,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      return RideRatingResult.failure('Sign in to rate this rider.');
    }
    if (stars < 1 || stars > 5) {
      return RideRatingResult.failure('Choose a rating from 1 to 5 stars.');
    }

    final String trimmedComment = (comment ?? '').trim();
    if (trimmedComment.length > 500) {
      return RideRatingResult.failure('Comment must be 500 characters or less.');
    }

    try {
      await _firestore.runTransaction((Transaction transaction) async {
        final DocumentReference<Map<String, dynamic>> tripRef =
            _trips.doc(tripId);
        final DocumentReference<Map<String, dynamic>> ratingRef = _firestore
            .collection(FirebaseCollections.riderRatings)
            .doc(tripId);

        final DocumentSnapshot<Map<String, dynamic>> tripSnap =
            await transaction.get(tripRef);
        if (!tripSnap.exists || tripSnap.data() == null) {
          throw StateError('Trip not found.');
        }
        final Map<String, dynamic> trip = tripSnap.data()!;
        if (trip['customerId'] != user.uid) {
          throw StateError('You cannot rate this ride.');
        }
        final String status =
            (trip['status'] as String?)?.trim().toLowerCase() ?? '';
        if (status != RideConstants.statusCompleted) {
          throw StateError('You can rate only after the ride is finished.');
        }
        if (trip['riderRated'] == true) {
          throw StateError('You already rated this rider.');
        }

        final DocumentSnapshot<Map<String, dynamic>> existingRating =
            await transaction.get(ratingRef);
        if (existingRating.exists) {
          throw StateError('You already rated this rider.');
        }

        final String riderId =
            ((trip['riderId'] ?? trip['assignedRiderId']) as String?)
                    ?.trim() ??
                '';
        if (riderId.isEmpty) {
          throw StateError('Rider is missing on this ride.');
        }

        transaction.set(ratingRef, <String, dynamic>{
          'orderId': tripId,
          'customerId': user.uid,
          'riderId': riderId,
          'stars': stars,
          'comment': trimmedComment,
          'status': 'visible',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.update(tripRef, <String, dynamic>{
          'riderRated': true,
          'riderRatingStars': stars,
        });
      });
      return RideRatingResult.success();
    } on StateError catch (e) {
      return RideRatingResult.failure(
        userFacingError(e, fallback: 'Could not submit rating.'),
      );
    } catch (e) {
      return RideRatingResult.failure(
        userFacingError(e, fallback: 'Could not submit rating.'),
      );
    }
  }

  Stream<RideFareConfig> watchRideFareConfig() {
    return _firestore
        .collection(FirebaseCollections.rideFareConfig)
        .doc(FirebaseCollections.rideFareRatesDocId)
        .snapshots()
        .map((DocumentSnapshot<Map<String, dynamic>> snap) {
      if (!snap.exists || snap.data() == null) {
        return RideFareConfig.defaults;
      }
      return RideFareConfig.fromMap(snap.data());
    });
  }
}

class RideRatingResult {
  const RideRatingResult._({required this.ok, this.message});

  factory RideRatingResult.success() => const RideRatingResult._(ok: true);

  factory RideRatingResult.failure(String message) =>
      RideRatingResult._(ok: false, message: message);

  final bool ok;
  final String? message;
}
