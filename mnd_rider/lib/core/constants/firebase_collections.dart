class FirebaseCollections {
  FirebaseCollections._();

  static const String orders = 'orders';
  static const String riders = 'riders';
  static const String vendors = 'vendors';
  static const String system = 'system';
  static const String orderSequenceDocId = 'order_sequence';
  static const String deviceTokens = 'device_tokens';
  static const String notifications = 'notifications';

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
}
