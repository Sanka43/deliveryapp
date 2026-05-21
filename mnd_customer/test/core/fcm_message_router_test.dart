import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnd_delivery_app/core/services/fcm_message_router.dart';

void main() {
  test('orderIdFromMessage reads orderId and order_id', () {
    expect(
      FcmMessageRouter.orderIdFromMessage(
        RemoteMessage(data: <String, dynamic>{'orderId': 'abc123'}),
      ),
      'abc123',
    );
    expect(
      FcmMessageRouter.orderIdFromMessage(
        RemoteMessage(data: <String, dynamic>{'order_id': 'xyz'}),
      ),
      'xyz',
    );
    expect(
      FcmMessageRouter.orderIdFromMessage(const RemoteMessage()),
      isNull,
    );
  });
}
