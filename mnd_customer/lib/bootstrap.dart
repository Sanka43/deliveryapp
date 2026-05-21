import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mnd_delivery_app/app/app.dart';
import 'package:mnd_delivery_app/core/services/firebase_messaging_service.dart';
import 'package:mnd_delivery_app/firebase_options.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
  await FirebaseMessagingService.initialize();
  runApp(
    const ProviderScope(
      child: MndDeliveryApp(),
    ),
  );
}
