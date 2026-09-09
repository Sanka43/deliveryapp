import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mnd_rider/core/config/rider_env_config.dart';
import 'package:mnd_rider/core/notifications/firebase_messaging_background.dart';
import 'package:mnd_rider/firebase_options.dart';

/// Initializes Firebase and platform services before [runApp].
Future<void> bootstrapRiderApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  if (!kIsWeb) {
    // Crashlytics has no web implementation — native platforms only.
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }
  // Must be registered before runApp — not from widget init — so data-only
  // pushes received while terminated/backgrounded are never dropped.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  // No-op if --dart-define=GOOGLE_MAPS_KEY was already passed.
  await RiderEnvConfig.loadNativeGoogleMapsApiKey();
}
