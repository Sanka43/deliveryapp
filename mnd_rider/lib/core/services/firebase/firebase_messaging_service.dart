import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:mnd_rider/core/constants/firebase_collections.dart';
import 'package:mnd_rider/core/notifications/firebase_messaging_background.dart';
import 'package:mnd_rider/core/notifications/rider_local_notifications.dart';
import 'package:mnd_rider/core/notifications/rider_push_message.dart';
import 'package:mnd_rider/core/notifications/rider_push_preferences.dart';

typedef RiderPushTapCallback = void Function(RiderPushMessage message);

/// FCM: permissions, topics, token sync, foreground/background/opened handlers.
///
/// Expected `data` payload from Cloud Functions / Admin SDK:
/// - `type`: `new_delivery_request` | `order_cancelled` | `delivery_completed` | `earnings`
/// - `orderId` (optional)
/// - `amountLkr` (optional, earnings)
/// - `title`, `body` (optional overrides)
class FirebaseMessagingService {
  FirebaseMessagingService({
    required FirebaseMessaging messaging,
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  })  : _messaging = messaging,
        _firestore = firestore,
        _auth = auth;

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static const String riderJobsTopic = 'mnd_rider_jobs';
  static const String riderEarningsTopic = 'mnd_rider_earnings';

  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  RiderPushTapCallback? _onNotificationTap;

  Future<void> initialize({RiderPushTapCallback? onNotificationTap}) async {
    _onNotificationTap = onNotificationTap;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    await RiderLocalNotifications.ensureInitialized(
      onTap: _handleLocalNotificationTap,
    );

    await _messaging.subscribeToTopic(riderJobsTopic);
    await _messaging.subscribeToTopic(riderEarningsTopic);
    await syncDeviceToken();

    _subscriptions
      ..add(_messaging.onTokenRefresh.listen((_) => syncDeviceToken()))
      ..add(FirebaseMessaging.onMessage.listen(_onForegroundMessage))
      ..add(FirebaseMessaging.onMessageOpenedApp.listen(_onOpenedApp));

    final RemoteMessage? initial = await _messaging.getInitialMessage();
    if (initial != null) {
      _onOpenedApp(initial);
    }
  }

  void dispose() {
    for (final StreamSubscription<dynamic> s in _subscriptions) {
      s.cancel();
    }
    _subscriptions.clear();
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final RiderPushMessage parsed = RiderPushMessage.fromRemoteMessage(message);
    if (!await RiderPushPreferences.isEnabledFor(parsed.type)) {
      return;
    }
    await RiderLocalNotifications.show(parsed);
  }

  void _onOpenedApp(RemoteMessage message) {
    final RiderPushMessage parsed = RiderPushMessage.fromRemoteMessage(message);
    _onNotificationTap?.call(parsed);
  }

  void _handleLocalNotificationTap(String? payload) {
    final RiderPushMessage? parsed = RiderLocalNotifications.parsePayload(payload);
    if (parsed != null) {
      _onNotificationTap?.call(parsed);
    }
  }

  /// Persists FCM token to `device_tokens` and `riders/{uid}`.
  Future<void> syncDeviceToken() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      return;
    }
    try {
      final String? token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        return;
      }
      final String docId = token.replaceAll('/', '_');
      final Timestamp now = Timestamp.now();

      await _firestore.collection(FirebaseCollections.deviceTokens).doc(docId).set(
        <String, dynamic>{
          'userId': user.uid,
          'token': token,
          'platform': defaultTargetPlatform.name,
          'app': 'mnd_rider',
          'role': 'rider',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await _firestore.collection(FirebaseCollections.riders).doc(user.uid).set(
        <String, dynamic>{
          'fcmToken': token,
          'fcmTokenUpdatedAt': now,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e, st) {
      debugPrint('FCM token sync failed: $e\n$st');
    }
  }

  Future<void> clearDeviceToken() async {
    try {
      final String? token = await _messaging.getToken();
      final User? user = _auth.currentUser;

      if (token != null && token.isNotEmpty) {
        final String docId = token.replaceAll('/', '_');
        await _firestore
            .collection(FirebaseCollections.deviceTokens)
            .doc(docId)
            .delete();
      }

      if (user != null) {
        await _firestore.collection(FirebaseCollections.riders).doc(user.uid).set(
          <String, dynamic>{
            'fcmToken': FieldValue.delete(),
            'fcmTokenUpdatedAt': FieldValue.delete(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await _messaging.deleteToken();
    } catch (e, st) {
      debugPrint('FCM clear token failed: $e\n$st');
    }
  }

  Future<void> unsubscribeOnSignOut() async {
    try {
      await _messaging.unsubscribeFromTopic(riderJobsTopic);
      await _messaging.unsubscribeFromTopic(riderEarningsTopic);
      await clearDeviceToken();
    } catch (_) {}
  }
}
