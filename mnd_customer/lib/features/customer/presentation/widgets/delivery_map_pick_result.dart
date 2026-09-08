/// Result of choosing a point on the map and reverse-geocoding it (or of
/// picking a Places Autocomplete suggestion).
class DeliveryMapPickResult {
  const DeliveryMapPickResult({
    required this.line1,
    required this.line2,
    required this.city,
    required this.latitude,
    required this.longitude,
    this.placeName,
  });

  final String line1;
  final String line2;
  final String city;
  final double latitude;
  final double longitude;

  /// Business/POI name (e.g. "Ranjan Lanka") when [line1] came from a
  /// Places Autocomplete selection rather than a reverse-geocoded pin.
  final String? placeName;
}
