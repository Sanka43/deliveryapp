/// Declarative route paths for [GoRouter].
class RoutePaths {
  RoutePaths._();

  static const String splash = '/auth/splash';
  static const String onboarding = '/auth/onboarding';
  static const String login = '/auth/login';
  static const String otp = '/auth/otp';
  static const String register = '/auth/register';
  static const String shell = '/home';
  static const String trip = '/trip';
  static const String orderDetail = '/order';
  static const String history = '/history';
  static const String transactions = '/earnings/transactions';
  static const String settings = '/settings';
  static const String profileEdit = '/profile/edit';

  static bool isPublicAuthRoute(String location) {
    return location.startsWith('/auth');
  }
}
