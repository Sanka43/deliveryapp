class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String otp = '/otp';
  static const String customer = '/customer';
  static const String customerSearch = '/customer/search';
  static const String customerFood = '/customer/food';
  static const String customerJobs = '/customer/jobs';
  static const String customerJobDetail = '/customer/jobs';
  static const String customerPostJob = '/customer/jobs/post';
  static const String customerSavedJobs = '/customer/jobs/saved';
  static const String customerMyJobPosts = '/customer/jobs/my-posts';
  static const String customerMyJobApplications = '/customer/jobs/my-applications';
  static const String customerStoreDetails = '/customer/store';
  static const String customerCart = '/customer/cart';
  static const String customerCheckout = '/customer/checkout';
  static const String customerOrders = '/customer/orders';
  static const String customerSavedAddresses = '/customer/addresses';
  static const String customerProfile = '/customer/profile';
  static const String customerProfileJobs = '/customer/profile/jobs';
  static const String customerEditProfile = '/customer/profile/edit';
  static const String customerNotificationSettings =
      '/customer/settings/notifications';
  static const String customerLanguage = '/customer/settings/language';

  /// GoRouter path pattern: [customerOrders]/:orderId/tracking
  static String customerOrderLiveTracking(String orderId) =>
      '$customerOrders/$orderId/tracking';

  /// Rider accounts must use the MND Rider app — customer build shows this gate.
  static const String wrongAppRider = '/wrong-app/rider';

  /// Vendor accounts must use the MND Vendor app — customer build shows this gate.
  static const String wrongAppVendor = '/wrong-app/vendor';

  static const String admin = '/admin';
}
