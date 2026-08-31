import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mnd_delivery_app/core/config/env_config.dart';

/// Driving route between two points (Google Directions API).
class RideDrivingRoute {
  const RideDrivingRoute({
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
    this.summary = '',
  });

  final List<LatLng> points;
  final double distanceKm;
  final int durationMinutes;
  final String summary;
}

final Provider<RideDirectionsService> rideDirectionsServiceProvider =
    Provider<RideDirectionsService>((Ref ref) {
  return RideDirectionsService(dio: Dio());
});

class RideDirectionsService {
  RideDirectionsService({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static const String _baseUrl =
      'https://maps.googleapis.com/maps/api/directions/json';

  Future<RideDrivingRoute?> fetchDrivingRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    List<LatLng> waypoints = const <LatLng>[],
  }) async {
    if (kIsWeb) {
      // Google's Directions REST API doesn't send CORS headers, so the
      // browser blocks a direct call — go through our own Cloud Function
      // instead (server-to-server, no CORS). Mobile keeps calling Google
      // directly below (works fine, no CORS in a native HTTP client).
      return _fetchViaCloudFunction(
        originLat: originLat,
        originLng: originLng,
        destLat: destLat,
        destLng: destLng,
        waypoints: waypoints,
      );
    }

    final String key = EnvConfig.googleMapsApiKey.trim();
    if (key.isEmpty) {
      debugPrint(
        '[RideDirectionsService] GOOGLE_MAPS_KEY dart-define is empty — '
        'skipping Directions call. Copy dart_defines.example.json to '
        'dart_defines.json, fill in GOOGLE_MAPS_KEY, and run with '
        '--dart-define-from-file=dart_defines.json (see README.md).',
      );
      return null;
    }

    final Map<String, dynamic> data;
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        _baseUrl,
        queryParameters: <String, dynamic>{
          'origin': '$originLat,$originLng',
          'destination': '$destLat,$destLng',
          'mode': 'driving',
          'alternatives': 'false',
          'units': 'metric',
          'region': 'lk',
          'key': key,
          if (waypoints.isNotEmpty)
            // Ordered (not optimized) — must match the customer's chosen
            // stop order, not the shortest route.
            'waypoints': waypoints
                .map((LatLng p) => '${p.latitude},${p.longitude}')
                .join('|'),
        },
      );
      data = Map<String, dynamic>.from(response.data as Map);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[RideDirectionsService] Directions request failed: $e');
      }
      return null;
    }

    final String status = (data['status'] as String?) ?? '';
    if (kDebugMode && waypoints.isNotEmpty) {
      final List<dynamic> routesRaw =
          data['routes'] as List<dynamic>? ?? <dynamic>[];
      final int? legCount = routesRaw.isEmpty
          ? null
          : ((routesRaw.first as Map)['legs'] as List<dynamic>?)?.length;
      debugPrint(
        '[RideDirectionsService] status="$status" waypoints=${waypoints.length} '
        'legs=$legCount (expect legs == waypoints + 1 if the stop was routed through)',
      );
    }
    if (status != 'OK') {
      if (kDebugMode) {
        debugPrint(
          '[RideDirectionsService] Directions API status="$status" '
          'error_message="${data['error_message']}"',
        );
      }
      return null;
    }

    final List<dynamic> routes = data['routes'] as List<dynamic>? ?? <dynamic>[];
    if (routes.isEmpty) {
      return null;
    }
    final Map<String, dynamic> route =
        Map<String, dynamic>.from(routes.first as Map);
    final Map<String, dynamic> overview = Map<String, dynamic>.from(
      route['overview_polyline'] as Map? ?? <String, dynamic>{},
    );
    final String encoded = (overview['points'] as String?) ?? '';
    if (encoded.isEmpty) {
      return null;
    }

    final List<LatLng> points = decodePolyline(encoded);
    if (points.length < 2) {
      return null;
    }

    double meters = 0;
    int seconds = 0;
    final List<dynamic> legs = route['legs'] as List<dynamic>? ?? <dynamic>[];
    for (final dynamic legRaw in legs) {
      final Map<String, dynamic> leg = Map<String, dynamic>.from(legRaw as Map);
      meters += ((leg['distance'] as Map?)?['value'] as num?)?.toDouble() ?? 0;
      seconds += ((leg['duration'] as Map?)?['value'] as num?)?.toInt() ?? 0;
    }

    return RideDrivingRoute(
      points: points,
      distanceKm: meters / 1000.0,
      durationMinutes: (seconds / 60).round().clamp(1, 9999),
      summary: (route['summary'] as String?)?.trim() ?? '',
    );
  }

  static const String _getDrivingRouteUrl =
      'https://asia-south1-mnd-masterndelivery.cloudfunctions.net/getDrivingRoute';

  Future<RideDrivingRoute?> _fetchViaCloudFunction({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required List<LatLng> waypoints,
  }) async {
    try {
      // Plain HTTPS POST rather than `cloud_functions`'s Callable client —
      // one fewer moving part, and matches the direct-Dio call the native
      // (non-web) branch below already makes to Google's own endpoint.
      final Response<dynamic> response = await _dio.post<dynamic>(
        _getDrivingRouteUrl,
        data: <String, dynamic>{
          'origin': '$originLat,$originLng',
          'destination': '$destLat,$destLng',
          if (waypoints.isNotEmpty)
            'waypoints': waypoints
                .map((LatLng p) => '${p.latitude},${p.longitude}')
                .toList(growable: false),
        },
        options: Options(contentType: 'application/json'),
      );
      final Map<String, dynamic> data =
          Map<String, dynamic>.from(response.data as Map);
      final String status = (data['status'] as String?) ?? '';
      if (status != 'OK') {
        if (kDebugMode) {
          debugPrint('[RideDirectionsService] getDrivingRoute status="$status"');
        }
        return null;
      }
      final String encoded = (data['points'] as String?) ?? '';
      if (encoded.isEmpty) {
        return null;
      }
      final List<LatLng> points = decodePolyline(encoded);
      if (points.length < 2) {
        return null;
      }
      final double meters = (data['distanceMeters'] as num?)?.toDouble() ?? 0;
      final int seconds = (data['durationSeconds'] as num?)?.toInt() ?? 0;
      return RideDrivingRoute(
        points: points,
        distanceKm: meters / 1000.0,
        durationMinutes: (seconds / 60).round().clamp(1, 9999),
        summary: (data['summary'] as String?)?.trim() ?? '',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[RideDirectionsService] getDrivingRoute call failed: $e');
      }
      return null;
    }
  }
}

/// Google encoded polyline algorithm → [LatLng] list.
///
/// Two deliberate departures from the textbook version, both required for
/// this to decode correctly once compiled for web (verified: the textbook
/// version decodes correctly on the Dart VM — Android/iOS — and silently
/// corrupts every point once it hits an unusually large coordinate delta
/// when compiled to JS for web):
///  1. Builds each 5-bit chunk group with multiplication (`factor *= 32`)
///     instead of `<< shift`. dart2js/DDC compile `int` shifts down to JS
///     `<<`, which truncates its operands to 32 bits.
///  2. Reconstructs the zigzag sign with arithmetic (`-(result >> 1) - 1`)
///     instead of `~(result >> 1)`. dart2js's `~` returns the unsigned
///     32-bit bit pattern instead of a proper negative Dart int — e.g.
///     `~6` comes back as `4294967289`, not `-7`.
List<LatLng> decodePolyline(String encoded) {
  final List<LatLng> coordinates = <LatLng>[];
  int index = 0;
  final int len = encoded.length;
  int lat = 0;
  int lng = 0;

  int readValue() {
    int result = 0;
    int factor = 1;
    int b;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result += (b & 0x1f) * factor;
      factor *= 32;
    } while (b >= 0x20);
    return (result & 1) != 0 ? -(result >> 1) - 1 : (result >> 1);
  }

  while (index < len) {
    lat += readValue();
    lng += readValue();
    coordinates.add(LatLng(lat / 1e5, lng / 1e5));
  }
  return coordinates;
}
