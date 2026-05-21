/// Result of choosing a point on the map and reverse-geocoding it.
class DeliveryMapPickResult {
  const DeliveryMapPickResult({
    required this.line1,
    required this.line2,
    required this.city,
    required this.latitude,
    required this.longitude,
  });

  final String line1;
  final String line2;
  final String city;
  final double latitude;
  final double longitude;
}
