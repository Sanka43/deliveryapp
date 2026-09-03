import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Map utilities for trip navigation and live tracking.
class RiderMapsHelper {
  RiderMapsHelper._();

  static LatLng? latLngFromOrder({
    double? lat,
    double? lng,
  }) {
    if (lat == null || lng == null) {
      return null;
    }
    if (lat == 0 && lng == 0) {
      return null;
    }
    return LatLng(lat, lng);
  }

  static CameraPosition cameraFor(LatLng target, {double zoom = 15}) {
    return CameraPosition(target: target, zoom: zoom);
  }

  static Set<Marker> singleMarker({
    required String id,
    required LatLng position,
    required String title,
    BitmapDescriptor? icon,
    double rotation = 0,
    bool flat = false,
  }) {
    return <Marker>{
      Marker(
        markerId: MarkerId(id),
        position: position,
        infoWindow: InfoWindow(title: title),
        icon: icon ?? BitmapDescriptor.defaultMarker,
        rotation: rotation,
        flat: flat,
      ),
    };
  }

  /// Straight-line fallback between two points, used only while a road
  /// route (see `RiderDirectionsService`) hasn't loaded yet or is unavailable.
  static List<LatLng> polylinePoints(LatLng from, LatLng to, {int segments = 24}) {
    if (segments < 2) {
      return <LatLng>[from, to];
    }
    return List<LatLng>.generate(segments + 1, (int i) {
      final double t = i / segments;
      return LatLng(
        from.latitude + (to.latitude - from.latitude) * t,
        from.longitude + (to.longitude - from.longitude) * t,
      );
    });
  }

  static LatLngBounds? boundsForPoints(Iterable<LatLng> points) {
    final List<LatLng> list = points.toList();
    if (list.isEmpty) {
      return null;
    }
    double minLat = list.first.latitude;
    double maxLat = list.first.latitude;
    double minLng = list.first.longitude;
    double maxLng = list.first.longitude;
    for (final LatLng p in list) {
      if (p.latitude < minLat) {
        minLat = p.latitude;
      }
      if (p.latitude > maxLat) {
        maxLat = p.latitude;
      }
      if (p.longitude < minLng) {
        minLng = p.longitude;
      }
      if (p.longitude > maxLng) {
        maxLng = p.longitude;
      }
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  static Future<void> animateToFit(
    GoogleMapController controller,
    Iterable<LatLng> points, {
    double padding = 72,
  }) async {
    final LatLngBounds? bounds = boundsForPoints(points);
    if (bounds == null) {
      return;
    }
    try {
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, padding),
      );
    } catch (_) {
      final LatLng center = LatLng(
        (bounds.southwest.latitude + bounds.northeast.latitude) / 2,
        (bounds.southwest.longitude + bounds.northeast.longitude) / 2,
      );
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(cameraFor(center, zoom: 14)),
      );
    }
  }
}
