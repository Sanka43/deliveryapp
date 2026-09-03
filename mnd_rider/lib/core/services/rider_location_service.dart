import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mnd_rider/app/providers/firebase_providers.dart';
import 'package:mnd_rider/core/constants/firebase_collections.dart';
import 'package:mnd_rider/features/auth/domain/rider_vehicle_type.dart';

final Provider<RiderLocationService> riderLocationServiceProvider =
    Provider<RiderLocationService>((Ref ref) {
  final RiderLocationService service = RiderLocationService(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Publishes GPS to `riders/{uid}` and `rider_locations/{uid}` (map tracking).
///
/// Both modes run a position stream backed by an Android foreground service so
/// updates keep flowing when the app is backgrounded:
/// - Online (idle): medium accuracy, 25 m distance filter.
/// - Active trip: high accuracy, 12 m distance filter, wake lock.
class RiderLocationService {
  RiderLocationService({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  })  : _firestore = firestore,
        _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  StreamSubscription<Position>? _positionSub;
  Timer? _retryTimer;
  bool _running = false;
  bool _tripMode = false;
  double? _lastPublishLat;
  double? _lastPublishLng;

  /// Cached passenger-trip vehicle type (`bike` / `wheel` / `car`).
  String? _cachedRideVehicleType;

  static const double _minPublishDistanceMeters = 20;

  /// Returns whether tracking ended up in the requested state. Callers that
  /// gate a Firestore presence write on this (e.g. going online) must check
  /// the result — a rider must never be marked online while GPS publishing
  /// silently failed to start.
  Future<bool> setTrackingEnabled(bool enabled) async {
    if (enabled) {
      return _start();
    }
    await _stop();
    return true;
  }

  /// Ensures location services + permission before going online.
  /// Returns a user-visible error message, or null when ready.
  Future<String?> ensureLocationReady() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return 'Turn on location services to go online.';
    }
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied) {
      return 'Location permission is required to go online.';
    }
    if (perm == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return 'Location permission is blocked. Enable it in system settings.';
    }
    return null;
  }

  /// High-frequency updates while on the live trip screen.
  Future<void> setTripMode(bool enabled) async {
    _tripMode = enabled;
    if (enabled && !_running) {
      await setTrackingEnabled(true);
      return;
    }
    if (!_running) {
      return;
    }
    await _restartTransport();
  }

  Future<bool> _start() async {
    if (_running) {
      return true;
    }
    final User? u = _auth.currentUser;
    if (u == null) {
      return false;
    }
    final LocationPermission perm = await _ensurePermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return false;
    }
    _running = true;
    await _restartTransport();
    return true;
  }

  Future<void> _restartTransport() async {
    _retryTimer?.cancel();
    _retryTimer = null;
    await _positionSub?.cancel();
    _positionSub = null;

    final User? u = _auth.currentUser;
    if (u == null || !_running) {
      return;
    }

    await _publishPosition(u.uid, await _readPosition());

    _positionSub = Geolocator.getPositionStream(
      locationSettings: _tripMode ? _tripSettings : _idleSettings,
    ).listen(
      (Position pos) async {
        final User? user = _auth.currentUser;
        if (user == null || !_running) {
          return;
        }
        await _publishPosition(user.uid, pos);
      },
      // A dead stream (provider hiccup, transient GPS/emulator error) must
      // not silently stop publishing forever — restart it. Without this a
      // rider can show "online" with a live-tracking stream that quietly
      // died minutes ago.
      onError: (Object error) {
        debugPrint('RiderLocationService: position stream error, retrying: $error');
        _scheduleRetry();
      },
      onDone: () {
        if (_running) {
          debugPrint('RiderLocationService: position stream closed unexpectedly, retrying');
          _scheduleRetry();
        }
      },
    );
  }

  void _scheduleRetry() {
    if (!_running || _retryTimer != null) {
      return;
    }
    _retryTimer = Timer(const Duration(seconds: 5), () {
      _retryTimer = null;
      if (_running) {
        _restartTransport();
      }
    });
  }

  LocationSettings get _tripSettings {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 12,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'MND Rider — active delivery',
          notificationText: 'Sharing your location for live tracking',
          enableWakeLock: true,
        ),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: 12,
        showBackgroundLocationIndicator: true,
        pauseLocationUpdatesAutomatically: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 12,
    );
  }

  /// Online but not on an active trip. Foreground service keeps offers and
  /// nearby matching working when the app leaves the foreground.
  LocationSettings get _idleSettings {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 25,
        intervalDuration: const Duration(seconds: 15),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'MND Rider — online',
          notificationText: 'Waiting for delivery offers nearby',
        ),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.medium,
        activityType: ActivityType.otherNavigation,
        distanceFilter: 25,
        showBackgroundLocationIndicator: true,
        pauseLocationUpdatesAutomatically: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: 25,
    );
  }

  Future<Position?> _readPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: _tripMode ? LocationAccuracy.high : LocationAccuracy.medium,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _stop() async {
    _running = false;
    _tripMode = false;
    _retryTimer?.cancel();
    _retryTimer = null;
    await _positionSub?.cancel();
    _positionSub = null;
    _lastPublishLat = null;
    _lastPublishLng = null;
    _cachedRideVehicleType = null;
  }

  Future<LocationPermission> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationPermission.denied;
    }
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (_tripMode && perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm;
  }

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

  Future<void> _publishPosition(String uid, Position? pos) async {
    if (pos == null) {
      return;
    }
    if (_lastPublishLat != null && _lastPublishLng != null) {
      final double moved = Geolocator.distanceBetween(
        _lastPublishLat!,
        _lastPublishLng!,
        pos.latitude,
        pos.longitude,
      );
      if (moved < _minPublishDistanceMeters) {
        return;
      }
    }
    _lastPublishLat = pos.latitude;
    _lastPublishLng = pos.longitude;

    try {
      // Deliberately does NOT touch `online` on the profile doc: a late in-flight
      // publish must never flip a rider back online after they toggled off.
      // Presence is owned by RiderPresenceRepository (toggle + heartbeat).
      final GeoPoint point = GeoPoint(pos.latitude, pos.longitude);
      final String? rideVehicleType = await _resolveRideVehicleType(uid);
      final WriteBatch batch = _firestore.batch();
      batch.set(
        _firestore.collection(FirebaseCollections.riders).doc(uid),
        <String, dynamic>{
          'currentLocation': point,
          'latitude': pos.latitude,
          'longitude': pos.longitude,
          'heading': pos.heading,
          'speed': pos.speed,
          'locationUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      // Public-safe tracking doc (no NIC/phone). `online: true` because this
      // publisher only runs while tracking is enabled for an online session.
      final Map<String, dynamic> locationPayload = <String, dynamic>{
        'riderId': uid,
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'location': point,
        'heading': pos.heading,
        'online': true,
        'locationUpdatedAt': FieldValue.serverTimestamp(),
      };
      if (rideVehicleType != null) {
        locationPayload['vehicleType'] = rideVehicleType;
      }
      batch.set(
        _firestore.collection(FirebaseCollections.riderLocations).doc(uid),
        locationPayload,
        SetOptions(merge: true),
      );
      await batch.commit();
    } catch (_) {}
  }

  void dispose() {
    unawaited(_stop());
  }
}
