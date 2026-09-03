class FirebaseCollections {
  FirebaseCollections._();

  /// Auth-backed profiles (customer, vendor, rider, admin); path `customers/{uid}`.
  static const String customers = 'customers';
  static const String riders = 'riders';
  static const String vendors = 'vendors';
  static const String products = 'products';
  static const String admins = 'admins';
  static const String banners = 'banners';
  /// Vendor standalone offers (admin-approved); shown on customer home + store pages.
  static const String offers = 'offers';
  /// Broad groups (Food, Grocery) for vendor registration — `label`, `order`, `active`.
  static const String shopCategories = 'shop_categories';
  /// Specific kinds under [shopCategories] — `label`, `order`, `active`, `categoryId`.
  static const String shopTypes = 'shop_types';
  /// Grocery product aisle labels for shop form + customer chips — `label`, `order`, `active`.
  static const String groceryAisles = 'grocery_aisles';
  static const String orders = 'orders';
  /// Customer→shop ratings after delivery; doc id = order id (one rating per order).
  static const String storeRatings = 'store_ratings';
  /// Customer→rider ratings after a delivery or a completed ride; doc id =
  /// order id or trip id (one rating per order/trip).
  static const String riderRatings = 'rider_ratings';
  /// Global counters / config (`order_sequence` doc holds monotonic `value` for tracking numbers).
  static const String system = 'system';
  static const String orderSequenceDocId = 'order_sequence';
  static const String notifications = 'notifications';
  static const String deviceTokens = 'device_tokens';

  /// Force/optional update gate — doc id per app (`customer`/`rider`/`shop`).
  static const String appConfig = 'app_config';

  /// Subcollection under [customers] / `{uid}` / saved_addresses / `{addressId}`.
  static const String savedAddresses = 'saved_addresses';

  /// Local employment listings (MND Jobs module).
  static const String jobs = 'jobs';
  static const String jobApplications = 'job_applications';
  static const String savedJobs = 'saved_jobs';
  static const String jobReports = 'job_reports';

  /// Live GPS only (no PII) — `rider_locations/{riderId}`.
  static const String riderLocations = 'rider_locations';

  /// Passenger ride trips (Uber-like booking).
  static const String trips = 'trips';
  /// Short-lived fare quotes created by `quoteRideFare` Cloud Function.
  static const String rideFareQuotes = 'ride_fare_quotes';
  /// Admin-managed base / per-km / min rates — doc id `rates`.
  static const String rideFareConfig = 'ride_fare_config';
  static const String rideFareRatesDocId = 'rates';

  /// `riders/{riderId}/withdrawals/{withdrawalId}`
  static const String riderWithdrawals = 'withdrawals';
}
