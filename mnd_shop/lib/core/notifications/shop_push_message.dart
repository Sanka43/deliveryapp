import 'package:firebase_messaging/firebase_messaging.dart';

enum ShopPushType {
  newOrder,
  orderReminder,
  orderCancelled,
  approval,
  unknown,
}

class ShopPushMessage {
  const ShopPushMessage({
    required this.type,
    required this.title,
    required this.body,
    this.orderId,
    this.status,
  });

  final ShopPushType type;
  final String title;
  final String body;
  final String? orderId;
  final String? status;

  static ShopPushMessage fromRemoteMessage(RemoteMessage message) {
    final Map<String, dynamic> data = message.data;
    final ShopPushType type = _parseType(_readString(data['type']));
    final RemoteNotification? notification = message.notification;
    return ShopPushMessage(
      type: type,
      title: _readString(data['title']) ??
          notification?.title ??
          _defaultTitle(type),
      body:
          _readString(data['body']) ?? notification?.body ?? _defaultBody(type),
      orderId: _readString(data['orderId'] ?? data['order_id']),
      status: _readString(data['status']),
    );
  }

  static ShopPushType _parseType(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'order_new':
      case 'new_order':
        return ShopPushType.newOrder;
      case 'order_reminder':
        return ShopPushType.orderReminder;
      case 'order_cancelled':
      case 'order_canceled':
        return ShopPushType.orderCancelled;
      case 'approval':
      case 'shop_approval':
        return ShopPushType.approval;
      default:
        return ShopPushType.unknown;
    }
  }

  static String? _readString(dynamic value) {
    if (value == null) {
      return null;
    }
    final String text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static String _defaultTitle(ShopPushType type) {
    return switch (type) {
      ShopPushType.newOrder => 'New order',
      ShopPushType.orderReminder => 'Order waiting',
      ShopPushType.orderCancelled => 'Order cancelled',
      ShopPushType.approval => 'Shop approval update',
      ShopPushType.unknown => 'MND Shop',
    };
  }

  static String _defaultBody(ShopPushType type) {
    return switch (type) {
      ShopPushType.newOrder => 'A new order is waiting for confirmation.',
      ShopPushType.orderReminder => 'Please confirm or reject this order.',
      ShopPushType.orderCancelled => 'An order was cancelled.',
      ShopPushType.approval => 'Your shop approval status changed.',
      ShopPushType.unknown => 'You have a new notification.',
    };
  }

  String get payloadForTap => <String, String>{
        'type': type.name,
        'orderId': ?orderId,
        'status': ?status,
      }.entries.map((MapEntry<String, String> entry) {
        return '${entry.key}=${Uri.encodeComponent(entry.value)}';
      }).join('&');

  factory ShopPushMessage.fromTapPayload(String? payload) {
    if (payload == null || payload.trim().isEmpty) {
      return const ShopPushMessage(
        type: ShopPushType.unknown,
        title: 'MND Shop',
        body: 'You have a new notification.',
      );
    }
    final Map<String, String> values = <String, String>{};
    for (final String part in payload.split('&')) {
      final int eq = part.indexOf('=');
      if (eq > 0) {
        values[part.substring(0, eq)] = Uri.decodeComponent(
          part.substring(eq + 1),
        );
      }
    }
    final ShopPushType type = switch (values['type']) {
      'newOrder' => ShopPushType.newOrder,
      'orderReminder' => ShopPushType.orderReminder,
      'orderCancelled' => ShopPushType.orderCancelled,
      'approval' => ShopPushType.approval,
      _ => ShopPushType.unknown,
    };
    return ShopPushMessage(
      type: type,
      title: _defaultTitle(type),
      body: _defaultBody(type),
      orderId: values['orderId'],
      status: values['status'],
    );
  }
}
