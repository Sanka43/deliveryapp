import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:mnd_delivery_app/features/customer/domain/entities/notification_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists toggles in [SharedPreferences] and mirrors them to FCM topics for the backend.
class NotificationSettingsRepository {
  NotificationSettingsRepository({
    FirebaseMessaging? messaging,
  }) : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  static const String _kOrderKey = 'notif_pref_order_updates';
  static const String _kPromoKey = 'notif_pref_promotions';

  /// Topics your Cloud Functions / admin sends to (must match server-side).
  static const String topicOrderUpdates = 'mnd_order_updates';
  static const String topicPromotions = 'mnd_promotions';

  Future<AppNotificationSettings> getSettings() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool order = prefs.getBool(_kOrderKey) ?? true;
    final bool promo = prefs.getBool(_kPromoKey) ?? false;
    return AppNotificationSettings(orderUpdates: order, promotions: promo);
  }

  /// Ensures FCM topic membership matches stored preferences.
  Future<AppNotificationSettings> loadAndSyncTopics() async {
    final AppNotificationSettings s = await getSettings();
    await _applyTopics(s);
    return s;
  }

  Future<void> setOrderUpdates(bool value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOrderKey, value);
    await _syncOrderTopic(value);
  }

  Future<void> setPromotions(bool value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPromoKey, value);
    await _syncPromoTopic(value);
  }

  Future<void> _applyTopics(AppNotificationSettings s) async {
    await _syncOrderTopic(s.orderUpdates);
    await _syncPromoTopic(s.promotions);
  }

  Future<void> _syncOrderTopic(bool subscribe) async {
    if (kIsWeb) {
      return;
    }
    try {
      if (subscribe) {
        await _messaging.subscribeToTopic(topicOrderUpdates);
      } else {
        await _messaging.unsubscribeFromTopic(topicOrderUpdates);
      }
    } catch (_) {}
  }

  Future<void> _syncPromoTopic(bool subscribe) async {
    if (kIsWeb) {
      return;
    }
    try {
      if (subscribe) {
        await _messaging.subscribeToTopic(topicPromotions);
      } else {
        await _messaging.unsubscribeFromTopic(topicPromotions);
      }
    } catch (_) {}
  }
}
