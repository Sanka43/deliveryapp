import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_rider/app/providers/firebase_providers.dart';
import 'package:mnd_rider/core/constants/firebase_collections.dart';
import 'package:mnd_rider/features/auth/domain/rider_vehicle_type.dart';

final Provider<RiderPresenceRepository> riderPresenceRepositoryProvider =
    Provider<RiderPresenceRepository>((Ref ref) {
  final RiderPresenceRepository repo = RiderPresenceRepository(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
  ref.onDispose(repo.stopHeartbeat);
  return repo;
});

class RiderPresenceRepository {
  RiderPresenceRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  })  : _firestore = firestore,
        _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// Server sweep flips `online: false` after ~3 min without a beat, so this
  /// allows a couple of missed beats before a rider is considered gone.
  static const Duration heartbeatInterval = Duration(seconds: 60);

  Timer? _heartbeat;
  String? _cachedRideVehicleType;

  Future<String?> _resolveRideVehicleType(String uid) async {
    if (_cachedRideVehicleType != null) {
      return _cachedRideVehicleType;
    }
    try {
      final DocumentSnapshot<Map<String, dynamic>> snap =
          await _firestore.collection(FirebaseCollections.riders).doc(uid).get();
      final RiderVehicleType? type = RiderVehicleType.fromFirestore(
        snap.data()?['vehicleType'] as String?,
      );
      if (type == null) {
        return null;
      }
      _cachedRideVehicleType = type.passengerTripVehicleTypes.first;
      return _cachedRideVehicleType;
    } catch (_) {
      return null;
    }
  }

  Future<void> setOnline(bool online) async {
    if (online) {
      startHeartbeat();
    } else {
      stopHeartbeat();
      _cachedRideVehicleType = null;
    }
    final User? u = _auth.currentUser;
    if (u == null) {
      return;
    }
    await _firestore.collection(FirebaseCollections.riders).doc(u.uid).set(
      <String, dynamic>{
        'online': online,
        'locationUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    // Keep public tracking doc in sync for customer maps (no-op if missing).
    try {
      final Map<String, dynamic> locationPatch = <String, dynamic>{
        'online': online,
        'locationUpdatedAt': FieldValue.serverTimestamp(),
      };
      if (online) {
        final String? rideVehicleType = await _resolveRideVehicleType(u.uid);
        if (rideVehicleType != null) {
          locationPatch['vehicleType'] = rideVehicleType;
        }
      }
      await _firestore
          .collection(FirebaseCollections.riderLocations)
          .doc(u.uid)
          .set(
            locationPatch,
            SetOptions(merge: true),
          );
    } catch (_) {}
  }

  /// Keeps `locationUpdatedAt` fresh while online so the server-side
  /// stale-presence sweep knows the app is still alive (dead-man switch).
  void startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(heartbeatInterval, (_) => _beat());
  }

  void stopHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = null;
  }

  Future<void> _beat() async {
    final User? u = _auth.currentUser;
    if (u == null) {
      stopHeartbeat();
      return;
    }
    try {
      await _firestore.collection(FirebaseCollections.riders).doc(u.uid).set(
        <String, dynamic>{
          'online': true,
          'locationUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // Transient write failures are fine; the next beat retries.
    }
  }
}
