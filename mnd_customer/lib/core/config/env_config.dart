import 'package:flutter/foundation.dart';

enum AppEnvironment { dev, staging, prod }

class EnvConfig {
  EnvConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.mnddelivery.com',
  );

  static const String env = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'dev',
  );

  static AppEnvironment get current {
    switch (env) {
      case 'prod':
        return AppEnvironment.prod;
      case 'staging':
        return AppEnvironment.staging;
      default:
        return AppEnvironment.dev;
    }
  }

  static bool get isProd => current == AppEnvironment.prod;

  static bool get isDev => current == AppEnvironment.dev;

  /// Shown under the app icon; includes env suffix outside production.
  static String get appTitle {
    switch (current) {
      case AppEnvironment.prod:
        return 'MND Delivery';
      case AppEnvironment.staging:
        return 'MND Delivery (Staging)';
      case AppEnvironment.dev:
        return 'MND Delivery (Dev)';
    }
  }

  /// Debug banner only in non-release dev builds.
  static bool get showDebugBanner => kDebugMode && isDev;
}
