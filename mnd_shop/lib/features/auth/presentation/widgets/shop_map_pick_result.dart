/// Result of [ShopMapPickerPage] — coordinates plus optional reverse-geocode hints.
class ShopMapPickResult {
  const ShopMapPickResult({
    required this.latitude,
    required this.longitude,
    this.suggestedAddressLine = '',
    this.suggestedCity = '',
  });

  final double latitude;
  final double longitude;
  final String suggestedAddressLine;
  final String suggestedCity;
}
