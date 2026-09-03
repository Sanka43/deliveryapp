import 'package:flutter/services.dart';

class RiderEnvConfig {
  RiderEnvConfig._();

  static const String _dartDefineMapsKey = String.fromEnvironment(
    'GOOGLE_MAPS_KEY',
    defaultValue: '',
  );

  static String _nativeMapsKey = '';

  /// Directions API key for road-following routes on the live trip map.
  ///
  /// Prefers `--dart-define=GOOGLE_MAPS_KEY=...` when passed; otherwise
  /// falls back to whatever [loadNativeGoogleMapsApiKey] found. No key
  /// literal lives in source either way.
  static String get googleMapsApiKey =>
      _dartDefineMapsKey.isNotEmpty ? _dartDefineMapsKey : _nativeMapsKey;

  static const MethodChannel _configChannel = MethodChannel(
    'com.mnd.mnd_rider/config',
  );

  /// Call once at startup (see `bootstrapRiderApp`). A bare `flutter run`
  /// with no dart-define previously meant every route silently fell back to
  /// a straight line — this reads the *same* key Gradle already wrote into
  /// AndroidManifest.xml from `android/local.properties`, via a native
  /// MethodChannel, so road-following routes work without extra flags.
  /// No-ops (leaves the straight-line fallback in place) on platforms
  /// without the native handler, e.g. iOS or web.
  static Future<void> loadNativeGoogleMapsApiKey() async {
    if (_dartDefineMapsKey.isNotEmpty) {
      return;
    }
    try {
      final String? key = await _configChannel.invokeMethod<String>(
        'googleMapsApiKey',
      );
      _nativeMapsKey = key?.trim() ?? '';
    } catch (_) {
      // Channel unimplemented on this platform, or the call failed.
    }
  }
}
