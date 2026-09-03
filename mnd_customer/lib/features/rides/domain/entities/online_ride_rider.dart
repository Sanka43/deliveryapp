import 'package:cloud_firestore/cloud_firestore.dart';

/// Online rider pin for the searching map (`rider_locations/{id}`).
class OnlineRideRider {
  const OnlineRideRider({
    required this.riderId,
    required this.latitude,
    required this.longitude,
    required this.vehicleType,
    this.heading,
  });

  final String riderId;
  final double latitude;
  final double longitude;
  final String vehicleType;
  final double? heading;

  static double? _readDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }

  static OnlineRideRider? fromDoc(
    String id,
    Map<String, dynamic> data,
  ) {
    double? lat;
    double? lng;
    final dynamic loc = data['location'];
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
    if (data['online'] != true) {
      return null;
    }
    final String vehicleType =
        (data['vehicleType'] as String?)?.trim().toLowerCase() ?? '';
    if (vehicleType.isEmpty) {
      return null;
    }
    return OnlineRideRider(
      riderId: (data['riderId'] as String?)?.trim().isNotEmpty == true
          ? (data['riderId'] as String).trim()
          : id,
      latitude: lat,
      longitude: lng,
      vehicleType: vehicleType,
      heading: _readDouble(data['heading']),
    );
  }
}
