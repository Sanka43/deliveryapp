class FirebaseCollections {
  FirebaseCollections._();

  static const String orders = 'orders';
  /// Passenger ride trips (hail / book a ride).
  static const String trips = 'trips';
  static const String riders = 'riders';
  static const String vendors = 'vendors';
  static const String system = 'system';
  static const String orderSequenceDocId = 'order_sequence';
  static const String deviceTokens = 'device_tokens';
  static const String notifications = 'notifications';

  /// Force/optional update gate — doc id per app (`customer`/`rider`/`shop`).
  static const String appConfig = 'app_config';

  /// Subcollection: `vendors/{vendorId}/notifications/{id}`
  static const String vendorNotifications = 'notifications';

  /// Rider wallet: `riders/{riderId}/wallet/summary`
  static const String riderWallet = 'wallet';
  static const String riderWalletSummaryId = 'summary';

  /// `riders/{riderId}/earnings_aggregates/{periodKey}`
  static const String riderEarningsAggregates = 'earnings_aggregates';

  /// `riders/{riderId}/transactions/{transactionId}`
  static const String riderTransactions = 'transactions';

  /// `riders/{riderId}/withdrawals/{withdrawalId}`
  static const String riderWithdrawals = 'withdrawals';

  /// Latest GPS snapshot per rider: `rider_locations/{riderId}`
  static const String riderLocations = 'rider_locations';

  /// `riders/{riderId}/notifications/{notificationId}`
  static const String riderNotifications = 'notifications';

  /// Cash collected but not yet handed to admin:
  /// `riders/{riderId}/cash_ledger/{entryId}`
  static const String riderCashLedger = 'cash_ledger';

  /// Handover requests: `riders/{riderId}/cash_settlements/{settlementId}`
  static const String riderCashSettlements = 'cash_settlements';

  /// Admin-editable fees and limits: `platform_config/fees`
  static const String platformConfig = 'platform_config';
  static const String platformFeesDocId = 'fees';
}
