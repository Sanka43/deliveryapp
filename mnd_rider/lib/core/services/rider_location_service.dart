import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mnd_rider/app/providers/firebase_providers.dart';
import 'package:mnd_rider/core/constants/firebase_collections.dart';

final Provider<RiderLocationService> riderLocationServiceProvider =
    Provider<RiderLocationService>((Ref ref) {
  final RiderLocationService service = RiderLocationService(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Publishes GPS to `riders/{uid}` for customer live tracking.
///
/// Normal online mode: periodic updates (~12s), balanced accuracy.
/// Active trip mode: position stream with distance filter + optional foreground
/// notification (Android) for reliable updates while navigating.
class RiderLocationService {
  RiderLocationService({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  })  : _firestore = firestore,
        _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Timer? _timer;
  StreamSubscription<Position>? _tripSub;
  bool _running = false;
  bool _tripMode = false;
  double? _lastPublishLat;
  double? _lastPublishLng;

  static const double _minPublishDistanceMeters = 20;

  Future<void> setTrackingEnabled(bool enabled) async {
    if (enabled) {
      await _start();
    } else {
      await _stop();
    }
  }

  /// High-frequency updates while on the live trip screen.
  Future<void> setTripMode(bool enabled) async {
    _tripMode = enabled;
    if (!_running) {
      return;
    }
    await _restartTransport();
  }

  Future<void> _start() async {
    if (_running) {
      return;
    }
    final User? u = _auth.currentUser;
    if (u == null) {
      return;
    }
    final LocationPermission perm = await _ensurePermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return;
    }
    _running = true;
    await _restartTransport();
  }

  Future<void> _restartTransport() async {
    _timer?.cancel();
    _timer = null;
    await _tripSub?.cancel();
    _tripSub = null;

    final User? u = _auth.currentUser;
    if (u == null || !_running) {
      return;
    }

    await _publishPosition(u.uid, await _readPosition());

    if (_tripMode) {
      _tripSub = Geolocator.getPositionStream(locationSettings: _tripSettings).listen(
        (Position pos) async {
          final User? user = _auth.currentUser;
          if (user == null || !_running) {
            return;
          }
          await _publishPosition(user.uid, pos);
        },
        onError: (_) {},
      );
    } else {
      _timer = Timer.periodic(const Duration(seconds: 12), (_) async {
        final User? user = _auth.currentUser;
        if (user == null || !_running) {
          return;
        }
        await _publishPosition(user.uid, await _readPosition());
      });
    }
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
    _timer?.cancel();
    _timer = null;
    await _tripSub?.cancel();
    _tripSub = null;
    _lastPublishLat = null;
    _lastPublishLng = null;
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
      await _firestore.collection(FirebaseCollections.riders).doc(uid).set(
        <String, dynamic>{
          'currentLocation': GeoPoint(pos.latitude, pos.longitude),
          'latitude': pos.latitude,
          'longitude': pos.longitude,
          'heading': pos.heading,
          'speed': pos.speed,
          'locationUpdatedAt': FieldValue.serverTimestamp(),
          'online': true,
        },
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  void dispose() {
    unawaited(_stop());
  }
}
