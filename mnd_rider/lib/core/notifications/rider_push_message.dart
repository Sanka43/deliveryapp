import 'package:firebase_messaging/firebase_messaging.dart';

/// FCM data payload `type` values for the rider app.
enum RiderPushType {
  newDeliveryRequest,
  orderCancelled,
  deliveryCompleted,
  earnings,
  rideUpdate,
  documentsExpiring,
  documentsExpired,

  /// Wallet/cash-hold pushes: `withdrawal_settled`, `cash_hold_started`,
  /// `cash_settlement_confirmed`, `cash_settlement_rejected`
  /// (functions/src/riderNotify.ts). Title/body always arrive in the payload
  /// from the backend, so the defaults below are only a safety net.
  walletUpdate,
  unknown,
}

/// Parsed push payload from FCM `data` + notification fields.
class RiderPushMessage {
  const RiderPushMessage({
    required this.type,
    this.orderId,
    this.tripId,
    this.title,
    this.body,
    this.amountLkr,
  });

  final RiderPushType type;
  final String? orderId;
  final String? tripId;
  final String? title;
  final String? body;
  final int? amountLkr;

  static RiderPushMessage fromRemoteMessage(RemoteMessage message) {
    final Map<String, dynamic> data = message.data;
    final String rawType = (data['type'] as String?)?.trim().toLowerCase() ?? '';
    final RiderPushType type = _parseType(rawType);

    final String? orderId = _readString(data['orderId'] ?? data['order_id']);
    final String? tripId = _readString(data['tripId'] ?? data['trip_id']);
    final int? amount = _readInt(data['amountLkr'] ?? data['amount_lkr']);

    final RemoteNotification? notification = message.notification;
    final String? title = _readString(data['title']) ?? notification?.title;
    final String? body = _readString(data['body']) ?? notification?.body;

    return RiderPushMessage(
      type: type,
      orderId: orderId,
      tripId: tripId,
      title: title ?? _defaultTitle(type),
      body: body ??
          _defaultBody(type, orderId: orderId, amountLkr: amount),
      amountLkr: amount,
    );
  }

  static RiderPushType _parseType(String raw) {
    switch (raw) {
      case 'new_delivery_request':
      case 'delivery_request':
      case 'new_order':
        return RiderPushType.newDeliveryRequest;
      case 'order_cancelled':
      case 'order_canceled':
        return RiderPushType.orderCancelled;
      case 'delivery_completed':
      case 'order_delivered':
        return RiderPushType.deliveryCompleted;
      case 'earnings':
      case 'earning':
        return RiderPushType.earnings;
      case 'ride_update':
      case 'trip_update':
        return RiderPushType.rideUpdate;
      case 'documents_expiring':
        return RiderPushType.documentsExpiring;
      case 'documents_expired':
        return RiderPushType.documentsExpired;
      case 'withdrawal_settled':
      case 'cash_hold_started':
      case 'cash_settlement_confirmed':
      case 'cash_settlement_rejected':
        return RiderPushType.walletUpdate;
      default:
        return RiderPushType.unknown;
    }
  }

  static String? _readString(dynamic value) {
    if (value == null) {
      return null;
    }
    final String s = value.toString().trim();
    return s.isEmpty ? null : s;
  }

  static int? _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    return int.tryParse(value?.toString() ?? '');
  }

  static String _defaultTitle(RiderPushType type) {
    return switch (type) {
      RiderPushType.newDeliveryRequest => 'New delivery request',
      RiderPushType.orderCancelled => 'Order cancelled',
      RiderPushType.deliveryCompleted => 'Delivery completed',
      RiderPushType.earnings => 'Earnings update',
      RiderPushType.rideUpdate => 'Ride update',
      RiderPushType.documentsExpiring => 'Document expiring soon',
      RiderPushType.documentsExpired => 'Document expired',
      RiderPushType.walletUpdate => 'Wallet update',
      RiderPushType.unknown => 'MND Rider',
    };
  }

  static String _defaultBody(
    RiderPushType type, {
    String? orderId,
    int? amountLkr,
  }) {
    return switch (type) {
      RiderPushType.newDeliveryRequest =>
        'A new job is available. Open the app to accept.',
      RiderPushType.orderCancelled =>
        orderId != null ? 'Order $orderId was cancelled.' : 'An order was cancelled.',
      RiderPushType.deliveryCompleted =>
        'Great job! Delivery marked complete.',
      RiderPushType.earnings => amountLkr != null && amountLkr > 0
          ? 'You earned Rs. $amountLkr.'
          : 'Check your earnings in the app.',
      RiderPushType.rideUpdate => 'Open the app for ride details.',
      RiderPushType.documentsExpiring =>
        'One of your documents is expiring soon. Renew it to keep taking jobs.',
      RiderPushType.documentsExpired =>
        'A document has expired. Renew it now — you can\'t go online until it\'s updated.',
      RiderPushType.walletUpdate => 'Open the app to see your wallet.',
      RiderPushType.unknown => 'You have a new notification.',
    };
  }

  String get payloadForTap => <String, String>{
        'type': type.name,
        if (orderId != null) 'orderId': orderId!,
        if (tripId != null) 'tripId': tripId!,
      }.entries.map((MapEntry<String, String> e) => '${e.key}=${e.value}').join('&');

  /// Parses tap payload from local notifications.
  factory RiderPushMessage.fromTapPayload(String? payload) {
    if (payload == null || payload.trim().isEmpty) {
      return const RiderPushMessage(type: RiderPushType.unknown);
    }
    final Map<String, String> map = <String, String>{};
    for (final String part in payload.split('&')) {
      final int eq = part.indexOf('=');
      if (eq > 0) {
        map[part.substring(0, eq)] = Uri.decodeComponent(part.substring(eq + 1));
      }
    }
    final RiderPushType type = switch (map['type']) {
      'newDeliveryRequest' => RiderPushType.newDeliveryRequest,
      'orderCancelled' => RiderPushType.orderCancelled,
      'deliveryCompleted' => RiderPushType.deliveryCompleted,
      'earnings' => RiderPushType.earnings,
      'rideUpdate' => RiderPushType.rideUpdate,
      'documentsExpiring' => RiderPushType.documentsExpiring,
      'documentsExpired' => RiderPushType.documentsExpired,
      'walletUpdate' => RiderPushType.walletUpdate,
      _ => RiderPushType.unknown,
    };
    return RiderPushMessage(
      type: type,
      orderId: map['orderId'],
      tripId: map['tripId'],
      title: _defaultTitle(type),
      body: _defaultBody(type, orderId: map['orderId']),
    );
  }
}
