import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:mnd_delivery_app/core/services/pwa_install_service_stub.dart'
    if (dart.library.js_interop) 'package:mnd_delivery_app/core/services/pwa_install_service_web.dart'
    as impl;
import 'package:shared_preferences/shared_preferences.dart';

const String kA2hsBannerDismissedKey = 'a2hs_banner_dismissed';

bool isPwaStandalone() => impl.isPwaStandalone();

bool canPromptPwaInstall() => impl.canPromptPwaInstall();

Future<bool> promptPwaInstall() => impl.promptPwaInstall();

/// Whether the home-page Add to Home Screen banner should be shown.
Future<bool> shouldShowA2hsBanner() async {
  if (!kIsWeb) {
    return false;
  }
  if (isPwaStandalone()) {
    return false;
  }
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getBool(kA2hsBannerDismissedKey) != true;
}

Future<void> dismissA2hsBanner() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setBool(kA2hsBannerDismissedKey, true);
}
