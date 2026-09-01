import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_rider/app/providers/firebase_providers.dart';
import 'package:mnd_rider/core/constants/firebase_collections.dart';
import 'package:mnd_rider/features/auth/domain/rider_vehicle_type.dart';
import 'package:mnd_rider/features/auth/presentation/providers/rider_approval_provider.dart';
import 'package:mnd_rider/features/delivery_requests/presentation/providers/order_request_session_provider.dart';
import 'package:mnd_rider/features/earnings/domain/rider_cash_hold_message.dart';
import 'package:mnd_rider/features/earnings/presentation/providers/rider_cash_hold_provider.dart';
import 'package:mnd_rider/features/profile/data/rider_profile_repository.dart';
import 'package:mnd_rider/features/profile/domain/rider_profile.dart';

final Provider<RiderTripsRepository> riderTripsRepositoryProvider =
    Provider<RiderTripsRepository>((Ref ref) {
  return RiderTripsRepository(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
    functions: ref.watch(firebaseFunctionsProvider),
  );
});

class RiderTripStop {
  const RiderTripStop({
    required this.lat,
    required this.lng,
    required this.label,
  });

  final double lat;
  final double lng;
  final String label;

  factory RiderTripStop.fromMap(Map<String, dynamic> m) {
    return RiderTripStop(
      lat: (m['lat'] as num?)?.toDouble() ?? 0,
      lng: (m['lng'] as num?)?.toDouble() ?? 0,
      label: (m['label'] as String?)?.trim() ?? '',
    );
  }
}

class RiderPassengerTrip {
  const RiderPassengerTrip({
    required this.id,
    required this.status,
    required this.vehicleType,
    required this.estimatedFareLkr,
    required this.distanceKm,
    required this.pickupLabel,
    required this.dropoffLabel,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.contactPhone,
    this.stops = const <RiderTripStop>[],
    this.currentStopIndex = 0,
    this.driverNote,
    this.createdAt,
    this.paymentMethod = '',
    this.paymentStatus = '',
  });

  final String id;
  final String status;
  final String vehicleType;
  final int estimatedFareLkr;
  final double distanceKm;
  final String pickupLabel;
  final String dropoffLabel;
  final double pickupLat;
  final double pickupLng;
  final double dropoffLat;
  final double dropoffLng;
  final String contactPhone;

  /// Intermediate stops between pickup and drop-off (0-2), in visit order.
  final List<RiderTripStop> stops;

  /// How many stops have been visited so far (advances only while
  /// `status == 'in_progress'`, via [RiderTripsRepository.advanceStop]).
  final int currentStopIndex;
  final String? driverNote;
  final DateTime? createdAt;

  /// `cash` or `payhere`.
  final String paymentMethod;

  /// `pending` | `paid` | `failed` | `refunded`.
  final String paymentStatus;

  /// PayHere rides are paid *after* the ride ends, not before — so a rider
  /// should never expect to collect cash for one of these regardless of
  /// whether `paymentStatus` has flipped to `paid` yet.
  bool get isOnlinePayment => paymentMethod.toLowerCase().trim() == 'payhere';

  bool get isPaid => paymentStatus.toLowerCase().trim() == 'paid';

  factory RiderPassengerTrip.fromDoc(String id, Map<String, dynamic> data) {
    Map<String, dynamic> place(String key) {
      final dynamic raw = data[key];
      if (raw is Map) {
        return Map<String, dynamic>.from(raw);
      }
      return <String, dynamic>{};
    }

    final Map<String, dynamic> pickup = place('pickup');
    final Map<String, dynamic> dropoff = place('dropoff');
    DateTime? created;
    final dynamic ts = data['createdAt'];
    if (ts is Timestamp) {
      created = ts.toDate();
    }
    final dynamic rawStops = data['stops'];
    final List<RiderTripStop> stops = rawStops is List
        ? rawStops
            .whereType<Map>()
            .map((Map e) => RiderTripStop.fromMap(Map<String, dynamic>.from(e)))
            .toList(growable: false)
        : const <RiderTripStop>[];

    return RiderPassengerTrip(
      id: id,
      status: (data['status'] as String?)?.trim() ?? '',
      vehicleType: (data['vehicleType'] as String?)?.trim() ?? '',
      estimatedFareLkr: (data['estimatedFareLkr'] as num?)?.toInt() ?? 0,
      distanceKm: (data['distanceKm'] as num?)?.toDouble() ?? 0,
      pickupLabel: (pickup['label'] as String?)?.trim() ?? '',
      dropoffLabel: (dropoff['label'] as String?)?.trim() ?? '',
      pickupLat: (pickup['lat'] as num?)?.toDouble() ?? 0,
      pickupLng: (pickup['lng'] as num?)?.toDouble() ?? 0,
      dropoffLat: (dropoff['lat'] as num?)?.toDouble() ?? 0,
      dropoffLng: (dropoff['lng'] as num?)?.toDouble() ?? 0,
      contactPhone: (data['contactPhone'] as String?)?.trim() ?? '',
      stops: stops,
      currentStopIndex: (data['currentStopIndex'] as num?)?.toInt() ?? 0,
      driverNote: (data['driverNote'] as String?)?.trim(),
      createdAt: created,
      paymentMethod: (data['paymentMethod'] as String?)?.trim() ?? '',
      paymentStatus: (data['paymentStatus'] as String?)?.trim() ?? '',
    );
  }
}

class RiderTripsRepository {
  RiderTripsRepository({
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

  Stream<List<RiderPassengerTrip>> watchOpenTrips() {
    if (_auth.currentUser == null) {
      return Stream<List<RiderPassengerTrip>>.value(
        const <RiderPassengerTrip>[],
      );
    }
    return _trips
        .where('openForRiders', isEqualTo: true)
        .where('status', isEqualTo: 'searching')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                    RiderPassengerTrip.fromDoc(d.id, d.data()),
              )
              .toList(growable: false),
        );
  }

  Stream<List<RiderPassengerTrip>> watchMyActiveTrips() {
    final User? u = _auth.currentUser;
    if (u == null) {
      return Stream<List<RiderPassengerTrip>>.value(
        const <RiderPassengerTrip>[],
      );
    }
    return _trips
        .where('assignedRiderId', isEqualTo: u.uid)
        .orderBy('createdAt', descending: true)
        .limit(15)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                    RiderPassengerTrip.fromDoc(d.id, d.data()),
              )
              .where(
                (RiderPassengerTrip t) =>
                    t.status == 'accepted' ||
                    t.status == 'arrived' ||
                    t.status == 'in_progress',
              )
              .toList(growable: false),
        );
  }

  Stream<RiderPassengerTrip?> watchTrip(String tripId) {
    final String id = tripId.trim();
    if (id.isEmpty || _auth.currentUser == null) {
      return Stream<RiderPassengerTrip?>.value(null);
    }
    return _trips.doc(id).snapshots().map((DocumentSnapshot<Map<String, dynamic>> snap) {
      if (!snap.exists || snap.data() == null) {
        return null;
      }
      return RiderPassengerTrip.fromDoc(snap.id, snap.data()!);
    });
  }

  Future<RiderPassengerTrip?> getTrip(String tripId) async {
    final String id = tripId.trim();
    if (id.isEmpty) {
      return null;
    }
    final DocumentSnapshot<Map<String, dynamic>> snap = await _trips.doc(id).get();
    if (!snap.exists || snap.data() == null) {
      return null;
    }
    return RiderPassengerTrip.fromDoc(snap.id, snap.data()!);
  }

  Stream<List<RiderPassengerTrip>> watchMyCompletedTrips({int limit = 40}) {
    final User? u = _auth.currentUser;
    if (u == null) {
      return Stream<List<RiderPassengerTrip>>.value(
        const <RiderPassengerTrip>[],
      );
    }
    return _trips
        .where('assignedRiderId', isEqualTo: u.uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                    RiderPassengerTrip.fromDoc(d.id, d.data()),
              )
              .where(
                (RiderPassengerTrip t) {
                  final String s = t.status.toLowerCase();
                  return s == 'completed' || s == 'cancelled';
                },
              )
              .toList(growable: false),
        );
  }

  Future<String?> claimTrip(String tripId) async {
    final User? u = _auth.currentUser;
    if (u == null) {
      return 'Not signed in.';
    }
    final String id = tripId.trim();
    if (id.isEmpty) {
      return 'Invalid trip.';
    }
    try {
      await _firestore.runTransaction((Transaction tx) async {
        final DocumentReference<Map<String, dynamic>> ref = _trips.doc(id);
        final DocumentSnapshot<Map<String, dynamic>> snap = await tx.get(ref);
        if (!snap.exists || snap.data() == null) {
          throw StateError('Trip not found.');
        }
        final Map<String, dynamic> data = snap.data()!;
        final String status =
            (data['status'] as String?)?.trim().toLowerCase() ?? '';
        final bool open = data['openForRiders'] == true;
        final String? assigned = (data['assignedRiderId'] as String?)?.trim();
        if (status != 'searching' || !open) {
          throw StateError('This ride is no longer available.');
        }
        if (assigned != null && assigned.isNotEmpty) {
          throw StateError('Another rider already claimed this ride.');
        }

        final DocumentSnapshot<Map<String, dynamic>> riderSnap = await tx.get(
          _firestore.collection(FirebaseCollections.riders).doc(u.uid),
        );
        // Firestore rules reject this write anyway (riderCashHoldActive), but
        // that surfaces as a bare permission error — say what's wrong instead.
        if (riderSnap.data()?['cashHoldActive'] == true) {
          throw StateError(cashHoldClaimMessage(riderSnap.data()));
        }
        final RiderVehicleType? riderVehicle = RiderVehicleType.fromFirestore(
          riderSnap.data()?['vehicleType'] as String?,
        );
        final String tripVehicle =
            (data['vehicleType'] as String?)?.trim().toLowerCase() ?? '';
        final List<String> allowed =
            riderVehicle?.passengerTripVehicleTypes ?? const <String>[];
        if (tripVehicle.isEmpty || !allowed.contains(tripVehicle)) {
          throw StateError('This ride does not match your vehicle type.');
        }

        tx.update(ref, <String, dynamic>{
          'assignedRiderId': u.uid,
          'riderId': u.uid,
          'openForRiders': false,
          'status': 'accepted',
          'riderAcceptedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      return null;
    } on StateError catch (e) {
      return e.message;
    } on FirebaseException catch (e) {
      return e.message ?? 'Could not claim ride.';
    } catch (e) {
      return e.toString();
    }
  }

  /// Marks the rider arrived at their current intermediate stop and moves
  /// on to the next leg. Does not touch `status` — only the final leg
  /// (heading to drop-off) completes the trip via [updateTripStatus].
  Future<String?> advanceStop(String tripId) async {
    final User? u = _auth.currentUser;
    if (u == null) {
      return 'Not signed in.';
    }
    try {
      final DocumentSnapshot<Map<String, dynamic>> snap =
          await _trips.doc(tripId).get();
      if (!snap.exists || snap.data() == null) {
        return 'Trip not found.';
      }
      final Map<String, dynamic> data = snap.data()!;
      final String status = (data['status'] as String?)?.trim() ?? '';
      final String? assigned = (data['assignedRiderId'] as String?)?.trim() ??
          (data['riderId'] as String?)?.trim();
      if (assigned != u.uid) {
        return 'This trip is not assigned to you.';
      }
      if (status != 'in_progress') {
        return 'Invalid trip status transition.';
      }
      final int stopCount = (data['stops'] as List?)?.length ?? 0;
      final int current = (data['currentStopIndex'] as num?)?.toInt() ?? 0;
      if (current >= stopCount) {
        return 'No more stops on this trip.';
      }
      await _trips.doc(tripId).update(<String, dynamic>{
        'currentStopIndex': current + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return null;
    } on FirebaseException catch (e) {
      return _friendlyTripUpdateError(tripId, e.message ?? 'Could not update trip.');
    }
  }

  /// A rules-rejected write (e.g. `permission-denied`) doesn't say why —
  /// re-reading the trip's current state gives a specific, useful message
  /// (e.g. "already cancelled") instead of a raw Firestore error string.
  Future<String> _friendlyTripUpdateError(
    String tripId,
    String fallback,
  ) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> snap =
          await _trips.doc(tripId).get();
      if (!snap.exists) {
        return 'This ride no longer exists.';
      }
      final String status =
          (snap.data()?['status'] as String?)?.trim().toLowerCase() ?? '';
      if (status == 'cancelled') {
        return 'This ride was already cancelled.';
      }
      if (status == 'completed') {
        return 'This ride was already completed.';
      }
    } catch (_) {
      // Best-effort re-check only — fall through to the original error.
    }
    return fallback;
  }

  Future<String?> updateTripStatus(String tripId, String nextStatus) async {
    final User? u = _auth.currentUser;
    if (u == null) {
      return 'Not signed in.';
    }
    final String normalized = nextStatus.trim().toLowerCase();
    if (normalized == 'completed') {
      return _completeTrip(tripId);
    }
    const Map<String, Set<String>> allowed = <String, Set<String>>{
      'accepted': <String>{'arrived', 'in_progress', 'cancelled', 'completed'},
      'arrived': <String>{'in_progress', 'cancelled', 'completed'},
      'in_progress': <String>{'completed', 'cancelled'},
    };
    try {
      final DocumentSnapshot<Map<String, dynamic>> snap =
          await _trips.doc(tripId).get();
      if (!snap.exists || snap.data() == null) {
        return 'Trip not found.';
      }
      final String from =
          (snap.data()!['status'] as String?)?.trim().toLowerCase() ?? '';
      final Set<String>? nextAllowed = allowed[from];
      if (nextAllowed == null || !nextAllowed.contains(normalized)) {
        return 'Invalid trip status transition.';
      }
      final String? assigned =
          (snap.data()!['assignedRiderId'] as String?)?.trim() ??
          (snap.data()!['riderId'] as String?)?.trim();
      if (assigned != u.uid) {
        return 'This trip is not assigned to you.';
      }

      final Map<String, dynamic> patch = <String, dynamic>{
        'status': normalized,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (normalized == 'arrived') {
        patch['arrivedAt'] = FieldValue.serverTimestamp();
      } else if (normalized == 'in_progress') {
        patch['startedAt'] = FieldValue.serverTimestamp();
      } else if (normalized == 'cancelled') {
        patch['cancelledAt'] = FieldValue.serverTimestamp();
        patch['cancelReason'] = 'rider_cancelled';
      }
      await _trips.doc(tripId).update(patch);
      return null;
    } on FirebaseException catch (e) {
      return _friendlyTripUpdateError(tripId, e.message ?? 'Could not update trip.');
    }
  }

  /// Server-authoritative trip completion. Only flips `status` to
  /// `completed` — payment is confirmed separately (see
  /// [confirmCashPayment] for cash trips; PayHere is paid online after the
  /// ride via a separate checkout flow).
  Future<String?> _completeTrip(String tripId) async {
    try {
      await _functions
          .httpsCallable('completeCashOrRideTrip')
          .call(<String, dynamic>{'tripId': tripId.trim()});
      return null;
    } on FirebaseFunctionsException catch (e) {
      return e.message ?? 'Could not complete trip.';
    } catch (e) {
      return e.toString();
    }
  }

  /// Rider confirms they collected cash for an already-completed trip —
  /// the only place `paymentStatus` flips to "paid" for cash trips.
  Future<String?> confirmCashPayment(String tripId) async {
    try {
      await _functions
          .httpsCallable('confirmCashRidePayment')
          .call(<String, dynamic>{'tripId': tripId.trim()});
      return null;
    } on FirebaseFunctionsException catch (e) {
      return e.message ?? 'Could not confirm payment.';
    } catch (e) {
      return e.toString();
    }
  }
}

final StreamProvider<List<RiderPassengerTrip>> openPassengerTripsProvider =
    StreamProvider<List<RiderPassengerTrip>>((Ref ref) {
  if (!ref.watch(riderIsApprovedToDriveProvider)) {
    return Stream<List<RiderPassengerTrip>>.value(const <RiderPassengerTrip>[]);
  }
  // Over the cash-in-hand limit: rules would reject the claim anyway, so don't
  // dangle rides the rider can't take. The blocking banner explains why.
  if (ref.watch(riderCashHoldActiveProvider)) {
    return Stream<List<RiderPassengerTrip>>.value(const <RiderPassengerTrip>[]);
  }
  return ref.watch(riderTripsRepositoryProvider).watchOpenTrips();
});

final Provider<AsyncValue<List<RiderPassengerTrip>>>
    matchedOpenPassengerTripsProvider =
    Provider<AsyncValue<List<RiderPassengerTrip>>>((Ref ref) {
  final AsyncValue<List<RiderPassengerTrip>> raw =
      ref.watch(openPassengerTripsProvider);
  final RiderProfile? profile =
      ref.watch(riderProfileStreamProvider).asData?.value;
  if (profile != null && !profile.acceptsPassengerRides) {
    return const AsyncValue<List<RiderPassengerTrip>>.data(
      <RiderPassengerTrip>[],
    );
  }
  final List<String> allowed =
      profile?.vehicleType.passengerTripVehicleTypes ?? const <String>[];
  // Once a rider rejects/lets a ride offer time out this session, don't
  // keep surfacing it here either — matches how a rejected delivery job
  // also disappears from its own open-jobs list, not just the offer popup.
  final Set<String> dismissed =
      ref.watch(orderRequestSessionProvider).dismissedOrderIds;
  return raw.whenData((List<RiderPassengerTrip> list) {
    return list
        .where((RiderPassengerTrip t) =>
            (allowed.isEmpty || allowed.contains(t.vehicleType)) &&
            !dismissed.contains(t.id))
        .toList(growable: false);
  });
});

final StreamProvider<List<RiderPassengerTrip>> myActivePassengerTripsProvider =
    StreamProvider<List<RiderPassengerTrip>>((Ref ref) {
  return ref.watch(riderTripsRepositoryProvider).watchMyActiveTrips();
});

final AutoDisposeStreamProviderFamily<RiderPassengerTrip?, String>
    riderPassengerTripProvider =
    StreamProvider.autoDispose.family<RiderPassengerTrip?, String>((Ref ref, String tripId) {
  return ref.watch(riderTripsRepositoryProvider).watchTrip(tripId);
});
