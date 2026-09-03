import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mnd_rider/core/config/rider_env_config.dart';

/// Driving route between two points (Google Directions API).
class RiderDrivingRoute {
  const RiderDrivingRoute({
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
  });

  final List<LatLng> points;
  final double distanceKm;
  final int durationMinutes;
}

final Provider<RiderDirectionsService> riderDirectionsServiceProvider =
    Provider<RiderDirectionsService>((Ref ref) {
  return RiderDirectionsService(dio: Dio());
});

class RiderDirectionsService {
  RiderDirectionsService({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static const String _baseUrl =
      'https://maps.googleapis.com/maps/api/directions/json';

  Future<RiderDrivingRoute?> fetchDrivingRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    final String key = RiderEnvConfig.googleMapsApiKey.trim();
    if (key.isEmpty) {
      return null;
    }

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
      },
    );

    final Map<String, dynamic> data =
        Map<String, dynamic>.from(response.data as Map);
    final String status = (data['status'] as String?) ?? '';
    if (status != 'OK') {
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

    final List<LatLng> points = decodeRiderPolyline(encoded);
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

    return RiderDrivingRoute(
      points: points,
      distanceKm: meters / 1000.0,
      durationMinutes: (seconds / 60).round().clamp(1, 9999),
    );
  }
}

/// Google encoded polyline algorithm → [LatLng] list.
List<LatLng> decodeRiderPolyline(String encoded) {
  final List<LatLng> coordinates = <LatLng>[];
  int index = 0;
  final int len = encoded.length;
  int lat = 0;
  int lng = 0;

  while (index < len) {
    int shift = 0;
    int result = 0;
    int b;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    final int dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lat += dlat;

    shift = 0;
    result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    final int dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lng += dlng;

    coordinates.add(LatLng(lat / 1e5, lng / 1e5));
  }
  return coordinates;
}
