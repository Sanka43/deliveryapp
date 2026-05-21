/// Local notification preferences (SharedPreferences).
class RiderNotificationSettings {
  const RiderNotificationSettings({
    required this.orderOffersEnabled,
    required this.deliveryUpdatesEnabled,
    required this.earningsAlertsEnabled,
    required this.promotionsEnabled,
  });

  static const RiderNotificationSettings defaults = RiderNotificationSettings(
    orderOffersEnabled: true,
    deliveryUpdatesEnabled: true,
    earningsAlertsEnabled: true,
    promotionsEnabled: false,
  );

  final bool orderOffersEnabled;
  final bool deliveryUpdatesEnabled;
  final bool earningsAlertsEnabled;
  final bool promotionsEnabled;

  RiderNotificationSettings copyWith({
    bool? orderOffersEnabled,
    bool? deliveryUpdatesEnabled,
    bool? earningsAlertsEnabled,
    bool? promotionsEnabled,
  }) {
    return RiderNotificationSettings(
      orderOffersEnabled: orderOffersEnabled ?? this.orderOffersEnabled,
      deliveryUpdatesEnabled:
          deliveryUpdatesEnabled ?? this.deliveryUpdatesEnabled,
      earningsAlertsEnabled: earningsAlertsEnabled ?? this.earningsAlertsEnabled,
      promotionsEnabled: promotionsEnabled ?? this.promotionsEnabled,
    );
  }
}
