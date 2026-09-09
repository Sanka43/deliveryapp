import 'package:firebase_analytics/firebase_analytics.dart';

/// Thin wrapper around [FirebaseAnalytics] for the handful of key events we
/// track — keeps call sites free of the raw API and gives one place to
/// extend event coverage later.
class AnalyticsService {
  AnalyticsService._();

  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  static Future<void> logLogin() => _analytics.logLogin(loginMethod: 'phone');

  static Future<void> logOrderPlaced({
    required String orderId,
    required double totalLkr,
  }) =>
      _analytics.logEvent(
        name: 'order_placed',
        parameters: <String, Object>{
          'order_id': orderId,
          'value': totalLkr,
          'currency': 'LKR',
        },
      );

  static Future<void> logCouponApplied(String code) => _analytics.logEvent(
        name: 'coupon_applied',
        parameters: <String, Object>{'coupon_code': code},
      );

  static Future<void> logReferralCodeRedeemed() =>
      _analytics.logEvent(name: 'referral_code_redeemed');
}
