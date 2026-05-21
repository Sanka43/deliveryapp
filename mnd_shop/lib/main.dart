import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:mnd_shop/app.dart';
import 'package:mnd_shop/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runMndShopApp();
}
