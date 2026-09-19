import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnd_delivery_app/features/orders/domain/entities/customer_order_detail.dart';
import 'package:mnd_delivery_app/features/orders/domain/entities/customer_order_summary.dart';

void main() {
  final DateTime when = DateTime(2026, 9, 20, 14, 30);

  group('CustomerOrderDetail order type', () {
    test('legacy order without orderType is standard', () {
      final CustomerOrderDetail d =
          CustomerOrderDetail.fromDoc('a', <String, dynamic>{'total': 500});
      expect(d.orderType, 'standard');
      expect(d.isEmergency, isFalse);
      expect(d.isScheduled, isFalse);
      expect(d.emergencyFee, 0);
    });

    test('emergency order exposes the fee', () {
      final CustomerOrderDetail d =
          CustomerOrderDetail.fromDoc('a', <String, dynamic>{
        'orderType': 'emergency',
        'emergencyFee': 200,
        'total': 900,
      });
      expect(d.isEmergency, isTrue);
      expect(d.emergencyFee, 200);
    });

    test('schedule order exposes the requested time', () {
      final CustomerOrderDetail d =
          CustomerOrderDetail.fromDoc('a', <String, dynamic>{
        'orderType': 'schedule',
        'scheduledFor': Timestamp.fromDate(when),
      });
      expect(d.isScheduled, isTrue);
      expect(d.scheduledFor, when);
    });

    test('schedule without a time is not treated as scheduled', () {
      final CustomerOrderDetail d = CustomerOrderDetail.fromDoc(
        'a',
        <String, dynamic>{'orderType': 'schedule'},
      );
      expect(d.isScheduled, isFalse);
    });
  });

  group('CustomerOrderSummary order type', () {
    test('unknown orderType falls back to standard', () {
      final CustomerOrderSummary s = CustomerOrderSummary.fromDoc(
        'a',
        <String, dynamic>{'orderType': 'bogus'},
      );
      expect(s.orderType, 'standard');
      expect(s.isEmergency, isFalse);
      expect(s.isScheduled, isFalse);
    });

    test('emergency and schedule are recognised', () {
      final CustomerOrderSummary e = CustomerOrderSummary.fromDoc(
        'a',
        <String, dynamic>{'orderType': 'emergency'},
      );
      final CustomerOrderSummary s =
          CustomerOrderSummary.fromDoc('b', <String, dynamic>{
        'orderType': 'schedule',
        'scheduledFor': Timestamp.fromDate(when),
      });
      expect(e.isEmergency, isTrue);
      expect(s.isScheduled, isTrue);
      expect(s.scheduledFor, when);
    });
  });
}
