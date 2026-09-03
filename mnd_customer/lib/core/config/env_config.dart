import 'package:flutter/foundation.dart';

enum AppEnvironment { dev, staging, prod }

class EnvConfig {
  EnvConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.mnddelivery.com',
  );

  /// Pass explicitly with `--dart-define=APP_ENV=prod|staging|dev`.
  /// When omitted: release builds → prod, otherwise → dev.
  static const String env = String.fromEnvironment(
    'APP_ENV',
    defaultValue: '',
  );

  /// Maps / Directions key, read via dart-define. In normal dev, this is
  /// supplied automatically by `--dart-define-from-file=dart_defines.json`
  /// (see mnd_customer/dart_defines.example.json + README.md) — no need to
  /// type `--dart-define=GOOGLE_MAPS_KEY=...` by hand each run. Android/iOS
  /// native map SDKs read their own key separately from
  /// `android/local.properties` / `ios/Flutter/Secrets.xcconfig`. No key in
  /// source.
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_KEY',
    defaultValue: '',
  );

  /// Admin dashboard in this APK. Store/release builds leave this false.
  /// Internal ops: `--dart-define=INCLUDE_ADMIN=true`.
  static const bool includeAdminUi = bool.fromEnvironment(
    'INCLUDE_ADMIN',
    defaultValue: false,
  );

  static String get _resolvedEnv {
    if (env.isNotEmpty) {
      return env;
    }
    return kReleaseMode ? 'prod' : 'dev';
  }

  static AppEnvironment get current {
    switch (_resolvedEnv) {
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
}
