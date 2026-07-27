class FirebaseCollections {
  FirebaseCollections._();

  static const String vendors = 'vendors';
  static const String products = 'products';
  static const String shopCategories = 'shop_categories';
  static const String shopTypes = 'shop_types';
  static const String orders = 'orders';
  static const String system = 'system';
  static const String orderSequenceDocId = 'order_sequence';
  static const String customers = 'customers';
  static const String deviceTokens = 'device_tokens';

  /// Subcollection: `vendors/{vendorId}/notifications/{notificationId}`
  static const String vendorNotifications = 'notifications';
  /// Subcollection: `vendors/{vendorId}/monthly_invoices/{yyyy-MM}`
  static const String vendorMonthlyInvoices = 'monthly_invoices';
  static const String vendorDailyStats = 'daily_stats';
  static const String vendorWeeklyStats = 'weekly_stats';
  static const String vendorMonthlyStats = 'monthly_stats';
  static const String vendorYearlyStats = 'yearly_stats';
  static const String vendorProductStats = 'product_stats';
  static const String vendorProductDailyStats = 'product_daily_stats';
}
