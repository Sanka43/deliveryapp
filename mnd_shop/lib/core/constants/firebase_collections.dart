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

  /// Subcollection: `vendors/{vendorId}/notifications/{notificationId}`
  static const String vendorNotifications = 'notifications';
}
