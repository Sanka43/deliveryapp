import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:mnd_shop/core/constants/firebase_collections.dart';
import 'package:mnd_shop/core/notifications/shop_local_notifications.dart';
import 'package:mnd_shop/core/notifications/shop_push_channels.dart';
import 'package:mnd_shop/core/notifications/shop_push_message.dart';
import 'package:mnd_shop/core/notifications/vendor_alert_sound.dart';

typedef ShopPushTapCallback = void Function(ShopPushMessage message);

class ShopFirebaseMessagingService {
  ShopFirebaseMessagingService({
    required FirebaseMessaging messaging,
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  }) : _messaging = messaging,
        _firestore = firestore,
        _auth = auth;

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  ShopPushTapCallback? _onNotificationTap;
  String _currentVendorId = '';
  bool _initialized = false;

  Future<void> initialize({
    required String vendorId,
    ShopPushTapCallback? onNotificationTap,
  }) async {
    _onNotificationTap = onNotificationTap;
    _currentVendorId = vendorId.trim();

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
    await ShopLocalNotifications.ensureInitialized(
      onTap: _handleLocalNotificationTap,
    );

    await syncDeviceToken(vendorId: _currentVendorId);

    if (!_initialized) {
      _subscriptions
        ..add(_messaging.onTokenRefresh.listen((_) {
          syncDeviceToken(vendorId: _currentVendorId).catchError(
            (Object e, StackTrace st) =>
                debugPrint('Shop FCM token refresh sync failed: $e\n$st'),
          );
        }))
        ..add(FirebaseMessaging.onMessage.listen(_onForegroundMessage))
        ..add(FirebaseMessaging.onMessageOpenedApp.listen(_onOpenedApp));
      final RemoteMessage? initial = await _messaging.getInitialMessage();
      if (initial != null) {
        _onOpenedApp(initial);
      }
      _initialized = true;
    }
  }

  void dispose() {
    for (final StreamSubscription<dynamic> subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _initialized = false;
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    await ShopLocalNotifications.show(
      ShopPushMessage.fromRemoteMessage(message),
    );
  }

  void _onOpenedApp(RemoteMessage message) {
    _onNotificationTap?.call(ShopPushMessage.fromRemoteMessage(message));
  }

  void _handleLocalNotificationTap(String? payload) {
    final ShopPushMessage? parsed = ShopLocalNotifications.parsePayload(
      payload,
    );
    if (parsed != null) {
      _onNotificationTap?.call(parsed);
    }
  }

  /// Writes preferred Android FCM channel/sound onto the vendor doc so Cloud
  /// Functions can target the channel the app created.
  Future<void> syncNotificationChannelPrefs({
    required String vendorId,
    VendorAlertSound? sound,
  }) async {
    final String storeId = vendorId.trim().isNotEmpty
        ? vendorId.trim()
        : _currentVendorId;
    if (storeId.isEmpty) {
      return;
    }
    final VendorAlertSound selected =
        sound ?? await ShopLocalNotifications.currentAlertSound();
    await ShopLocalNotifications.ensureOrdersChannel(selected);
    try {
      await _firestore
          .collection(FirebaseCollections.vendors)
          .doc(storeId)
          .set(<String, dynamic>{
        'androidNotificationChannelId':
            ShopPushChannels.ordersChannelIdFor(selected),
        'androidNotificationSound': selected.androidRawName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e, st) {
      debugPrint('Shop notification channel sync failed: $e\n$st');
    }
  }

  Future<void> syncDeviceToken({required String vendorId}) async {
    final User? user = _auth.currentUser;
    final String storeId = vendorId.trim();
    if (user == null || storeId.isEmpty) {
      return;
    }
    try {
      final String? token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        return;
      }
      final String tokenDocId = token.replaceAll('/', '_');
      final Timestamp now = Timestamp.now();
      final VendorAlertSound selected =
          await ShopLocalNotifications.currentAlertSound();

      await _firestore
          .collection(FirebaseCollections.deviceTokens)
          .doc(tokenDocId)
          .set(<String, dynamic>{
        'userId': user.uid,
        'vendorId': storeId,
        'token': token,
        'platform': defaultTargetPlatform.name,
        'app': 'mnd_shop',
        'role': 'vendor',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _firestore
          .collection(FirebaseCollections.vendors)
          .doc(storeId)
          .set(<String, dynamic>{
        'fcmToken': token,
        'fcmTokenUpdatedAt': now,
        'androidNotificationChannelId':
            ShopPushChannels.ordersChannelIdFor(selected),
        'androidNotificationSound': selected.androidRawName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e, st) {
      debugPrint('Shop FCM token sync failed: $e\n$st');
    }
  }
}
