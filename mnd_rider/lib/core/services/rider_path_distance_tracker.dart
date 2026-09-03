import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Accumulates haversine path length while the rider is delivering to customer.
class RiderPathDistanceTracker {
  RiderPathDistanceTracker({this.minStepMeters = 8});

  final double minStepMeters;

  StreamSubscription<Position>? _sub;
  double _traveledKm = 0;
  double? _lastLat;
  double? _lastLng;
  final ValueNotifier<double> traveledKmListenable = ValueNotifier<double>(0);

  double get traveledKm => _traveledKm;

  bool get isTracking => _sub != null;

  Future<void> start() async {
    if (_sub != null) {
      return;
    }
    _traveledKm = 0;
    _lastLat = null;
    _lastLng = null;
    traveledKmListenable.value = 0;

    try {
      final Position seed = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _lastLat = seed.latitude;
      _lastLng = seed.longitude;
    } catch (_) {}

    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 8,
      ),
    ).listen(
      _onPosition,
      onError: (_) {},
    );
  }

  void _onPosition(Position pos) {
    if (_lastLat != null && _lastLng != null) {
      final double meters = Geolocator.distanceBetween(
        _lastLat!,
        _lastLng!,
        pos.latitude,
        pos.longitude,
      );
      if (meters >= minStepMeters) {
        _traveledKm += meters / 1000.0;
        traveledKmListenable.value = _traveledKm;
        _lastLat = pos.latitude;
        _lastLng = pos.longitude;
      }
    } else {
      _lastLat = pos.latitude;
      _lastLng = pos.longitude;
    }
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  void dispose() {
    unawaited(stop());
    traveledKmListenable.dispose();
  }
}
