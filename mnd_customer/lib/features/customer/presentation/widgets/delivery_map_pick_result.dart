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
    this.phone,
  });

  final String line1;
  final String line2;
  final String city;

  /// Null when this came from a saved address that was never pinned on the
  /// map — the address text is still usable, just without exact coordinates
  /// (delivery fee falls back to the flat/estimated rate for those).
  final double? latitude;
  final double? longitude;

  /// Business/POI name (e.g. "Ranjan Lanka") when [line1] came from a
  /// Places Autocomplete selection rather than a reverse-geocoded pin.
  final String? placeName;

  /// Set only when this result came from picking a saved address — never
  /// present for a dropped pin or a Places Autocomplete selection.
  final String? phone;
}
