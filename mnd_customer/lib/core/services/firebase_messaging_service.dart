import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle message for background isolate if needed.
}

class FirebaseMessagingService {
  FirebaseMessagingService._();

  static Future<void> initialize() async {
    // Web: never prompt for notifications on first paint (PageSpeed / UX).
    // Users enable push from Notification Settings after a gesture.
    if (kIsWeb) {
      return;
    }
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  /// Call after first frame — must not run before [runApp].
  static Future<void> requestPermissionAfterFirstFrame() async {
    if (kIsWeb) {
      return;
    }
    await FirebaseMessaging.instance.requestPermission();
  }
}
