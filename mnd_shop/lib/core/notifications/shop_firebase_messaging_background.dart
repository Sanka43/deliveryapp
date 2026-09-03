import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mnd_shop/core/notifications/shop_local_notifications.dart';
import 'package:mnd_shop/core/notifications/shop_push_message.dart';
import 'package:mnd_shop/firebase_options.dart';

@pragma('vm:entry-point')
Future<void> shopFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  // When FCM includes a notification payload, Android already shows the system
  // tray item. Only show a local notification for data-only messages.
  if (message.notification != null) {
    return;
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await ShopLocalNotifications.ensureInitialized();
  await ShopLocalNotifications.show(ShopPushMessage.fromRemoteMessage(message));
}
