class FirebaseCollections {
  FirebaseCollections._();

  static const String vendors = 'vendors';
  static const String products = 'products';
  /// Standalone shop offers (pending → admin approved → customer banners).
  static const String offers = 'offers';
  static const String shopCategories = 'shop_categories';
  static const String shopTypes = 'shop_types';
  /// Grocery product aisle labels — `label`, `order`, `active`.
  static const String groceryAisles = 'grocery_aisles';
  static const String orders = 'orders';
  static const String system = 'system';
  static const String orderSequenceDocId = 'order_sequence';
  static const String customers = 'customers';
  static const String riders = 'riders';
  static const String deviceTokens = 'device_tokens';

  /// Force/optional update gate — doc id per app (`customer`/`rider`/`shop`).
  static const String appConfig = 'app_config';

  /// Employment jobs (shared with customer/admin apps).
  static const String jobs = 'jobs';
  static const String jobApplications = 'job_applications';

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
