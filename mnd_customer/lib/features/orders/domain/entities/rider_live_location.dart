import 'package:cloud_firestore/cloud_firestore.dart';

/// Live coordinates streamed from [FirebaseCollections.riders] / `{riderId}`.
///
/// Supports `currentLocation` / `location` as [GeoPoint], or top-level
/// `latitude` / `longitude`. Optional `heading` (degrees) for marker rotation.
class RiderLiveLocation {
  const RiderLiveLocation({
    required this.latitude,
    required this.longitude,
    this.heading,
    this.updatedAt,
  });

  final double latitude;
  final double longitude;
  final double? heading;
  final DateTime? updatedAt;

  static double? _readDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }

  /// Returns null when the document has no usable coordinates.
  static RiderLiveLocation? fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return null;
    }
    double? lat;
    double? lng;
    final dynamic loc = data['currentLocation'] ?? data['location'];
    if (loc is GeoPoint) {
      lat = loc.latitude;
      lng = loc.longitude;
    } else {
      lat = _readDouble(data['latitude']);
      lng = _readDouble(data['longitude']);
    }
    if (lat == null || lng == null) {
      return null;
    }
    final Timestamp? ts =
        data['locationUpdatedAt'] as Timestamp? ?? data['updatedAt'] as Timestamp?;
    return RiderLiveLocation(
      latitude: lat,
      longitude: lng,
      heading: _readDouble(data['heading']),
      updatedAt: ts?.toDate(),
    );
  }
}
