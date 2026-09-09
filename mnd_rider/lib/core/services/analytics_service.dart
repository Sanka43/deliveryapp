import 'package:firebase_analytics/firebase_analytics.dart';

/// Thin wrapper around [FirebaseAnalytics] — keeps call sites free of the
/// raw API and gives one place to extend event coverage later.
class AnalyticsService {
  AnalyticsService._();

  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  static Future<void> logLogin() => _analytics.logLogin(loginMethod: 'phone');
}
