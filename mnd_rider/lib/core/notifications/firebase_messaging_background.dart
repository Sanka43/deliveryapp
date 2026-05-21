import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mnd_rider/core/notifications/rider_local_notifications.dart';
import 'package:mnd_rider/core/notifications/rider_push_message.dart';
import 'package:mnd_rider/core/notifications/rider_push_preferences.dart';
import 'package:mnd_rider/firebase_options.dart';

/// Top-level FCM background handler (isolate).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final RiderPushMessage parsed = RiderPushMessage.fromRemoteMessage(message);
  if (!await RiderPushPreferences.isEnabledFor(parsed.type)) {
    return;
  }
  await RiderLocalNotifications.ensureInitialized();
  await RiderLocalNotifications.show(parsed);
}
