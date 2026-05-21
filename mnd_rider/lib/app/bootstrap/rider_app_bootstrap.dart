import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:mnd_rider/firebase_options.dart';

/// Initializes Firebase and platform services before [runApp].
Future<void> bootstrapRiderApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}
