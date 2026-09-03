import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mnd_delivery_app/app/app.dart';
import 'package:mnd_delivery_app/core/config/env_config.dart';
import 'package:mnd_delivery_app/core/services/firebase_messaging_service.dart';
import 'package:mnd_delivery_app/core/services/google_maps_web_loader.dart';
import 'package:mnd_delivery_app/features/auth/presentation/providers/guest_browsing_provider.dart';
import 'package:mnd_delivery_app/features/auth/presentation/providers/user_role_provider.dart';
import 'package:mnd_delivery_app/firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Bundle fonts under google_fonts/ — avoid runtime fonts.gstatic.com fetches.
  GoogleFonts.config.allowRuntimeFetching = false;
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  if (kIsWeb) {
    // Phone auth reCAPTCHA must match the page origin (mnd.lk / *.web.app).
    // Newer Firebase Auth builds reject setting this after initializeApp — never
    // block cold start if the setter is unavailable on this platform/version.
    final String host = Uri.base.host;
    if (host.isNotEmpty &&
        host != 'localhost' &&
        host != '127.0.0.1') {
      try {
        FirebaseAuth.instance.customAuthDomain = host;
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('bootstrap: customAuthDomain skipped for $host → $e\n$st');
        }
      }
    }
    await ensureGoogleMapsWebScript(EnvConfig.googleMapsApiKey);
  }
  if (!kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      kDebugMode) {
    // Keep reCAPTCHA fallback opt-in for local testing. If this is always true,
    // Android phone auth jumps to browser (Chrome Custom Tab) every attempt.
    const bool forceRecaptchaFlow = bool.fromEnvironment(
      'FORCE_RECAPTCHA_FLOW',
      defaultValue: false,
    );
    if (forceRecaptchaFlow) {
      await FirebaseAuth.instance.setSettings(forceRecaptchaFlow: true);
    }
  }
  // Register FCM background handler only — permission is requested after first
  // frame so it never blocks runApp / cold start.
  await FirebaseMessagingService.initialize();

  // Warm last-known role + guest browse before first frame.
  String? cachedRole;
  bool guestBrowsing = false;
  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    cachedRole = prefs.getString(kLastUserRolePrefsKey)?.trim().toLowerCase();
    if (cachedRole != null && cachedRole.isEmpty) {
      cachedRole = null;
    }
    guestBrowsing = prefs.getBool(kGuestBrowsingPrefsKey) ?? false;
  } catch (_) {
    cachedRole = null;
    guestBrowsing = false;
  }

  runApp(
    ProviderScope(
      overrides: <Override>[
        cachedUserRoleProvider.overrideWith((Ref ref) => cachedRole),
        guestBrowsingProvider.overrideWith((Ref ref) => guestBrowsing),
      ],
      child: const MndDeliveryApp(),
    ),
  );
}
