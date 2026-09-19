import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnd_rider/features/delivery_requests/domain/rider_delivery_request.dart';
import 'package:mnd_rider/features/orders/data/rider_orders_repository.dart';
import 'package:mnd_rider/features/orders/domain/rider_order_detail.dart';

RiderOrderDetail _detail(Map<String, dynamic> extra) {
  return RiderOrderDetail.fromDoc('o1', <String, dynamic>{
    'storeName': 'Shop',
    'status': 'ready',
    ...extra,
  });
}

void main() {
  final DateTime when = DateTime(2026, 9, 20, 14, 30);

  group('RiderAssignedOrder', () {
    test('standard order has no badges', () {
      final RiderAssignedOrder o =
          RiderAssignedOrder.fromDetail(_detail(<String, dynamic>{}));
      expect(o.isEmergency, isFalse);
      expect(o.scheduledFor, isNull);
    });

    test('emergency order is flagged', () {
      final RiderAssignedOrder o = RiderAssignedOrder.fromDetail(
        _detail(<String, dynamic>{'orderType': 'emergency'}),
      );
      expect(o.isEmergency, isTrue);
    });

    test('scheduled order carries its time', () {
      final RiderAssignedOrder o = RiderAssignedOrder.fromDetail(
        _detail(<String, dynamic>{
          'orderType': 'schedule',
          'scheduledFor': Timestamp.fromDate(when),
        }),
      );
      expect(o.scheduledFor, when);
    });
  });

  group('RiderDeliveryRequest', () {
    RiderDeliveryRequest build(Map<String, dynamic> extra) {
      return RiderDeliveryRequest.fromEnriched(
        order: _detail(extra),
        riderLat: null,
        riderLng: null,
      );
    }

    test('offer keeps emergency and schedule info', () {
      expect(build(<String, dynamic>{'orderType': 'emergency'}).isEmergency,
          isTrue);
      expect(
        build(<String, dynamic>{
          'orderType': 'schedule',
          'scheduledFor': Timestamp.fromDate(when),
        }).scheduledFor,
        when,
      );
    });

    test('type survives copy helpers and the detail round-trip', () {
      final RiderDeliveryRequest r = build(<String, dynamic>{
        'orderType': 'schedule',
        'scheduledFor': Timestamp.fromDate(when),
      }).withDeliveryType(RiderDeliveryType.express).withRiderPosition(
            riderLat: 6.9,
            riderLng: 79.8,
          );
      expect(r.scheduledFor, when);
      final RiderOrderDetail d = r.toOrderDetail();
      expect(d.isScheduled, isTrue);
      expect(d.scheduledFor, when);
    });
  });
}
