class FirebaseCollections {
  FirebaseCollections._();

  /// Auth-backed profiles (customer, vendor, rider, admin); path `customers/{uid}`.
  static const String customers = 'customers';
  static const String riders = 'riders';
  static const String vendors = 'vendors';
  static const String products = 'products';
  static const String admins = 'admins';
  static const String banners = 'banners';
  /// Broad groups (Food, Grocery) for vendor registration — `label`, `order`, `active`.
  static const String shopCategories = 'shop_categories';
  /// Specific kinds under [shopCategories] — `label`, `order`, `active`, `categoryId`.
  static const String shopTypes = 'shop_types';
  static const String orders = 'orders';
  /// Customer→shop ratings after delivery; doc id = order id (one rating per order).
  static const String storeRatings = 'store_ratings';
  /// Global counters / config (`order_sequence` doc holds monotonic `value` for tracking numbers).
  static const String system = 'system';
  static const String orderSequenceDocId = 'order_sequence';
  static const String notifications = 'notifications';
  static const String deviceTokens = 'device_tokens';

  /// Subcollection under [customers] / `{uid}` / saved_addresses / `{addressId}`.
  static const String savedAddresses = 'saved_addresses';

  /// Local employment listings (MND Jobs module).
  static const String jobs = 'jobs';
  static const String jobApplications = 'job_applications';
  static const String savedJobs = 'saved_jobs';
  static const String jobReports = 'job_reports';
}
