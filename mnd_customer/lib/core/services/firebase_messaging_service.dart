import 'package:firebase_messaging/firebase_messaging.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle message for background isolate if needed.
}

class FirebaseMessagingService {
  FirebaseMessagingService._();

  static Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    final FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();
  }
}
