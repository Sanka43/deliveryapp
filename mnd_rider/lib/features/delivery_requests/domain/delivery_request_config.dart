/// Tunables for the rider order-request pipeline.
class DeliveryRequestConfig {
  const DeliveryRequestConfig({
    this.maxPickupRadiusKm = 25,
    this.offerTimeoutSeconds = 45,
    this.maxConcurrentOffers = 20,
  });

  /// Max distance from rider GPS to vendor pickup (km).
  final double maxPickupRadiusKm;

  /// Auto-dismiss offer after this many seconds.
  final int offerTimeoutSeconds;

  final int maxConcurrentOffers;

  static const DeliveryRequestConfig defaults = DeliveryRequestConfig();
}
