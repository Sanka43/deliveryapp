import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnd_shop/features/dashboard/domain/vendor_pending_order.dart';
import 'package:mnd_shop/features/orders/presentation/widgets/vendor_order_type_banner.dart';

VendorPendingOrder _order(Map<String, dynamic> extra) =>
    VendorPendingOrder.fromFirestore('o1', <String, dynamic>{
      'status': 'placed',
      ...extra,
    });

Future<void> _pump(WidgetTester tester, VendorPendingOrder order) {
  return tester.pumpWidget(
    MaterialApp(home: Scaffold(body: VendorOrderTypeBanner(order: order))),
  );
}

void main() {
  test('order type is parsed from the order document', () {
    expect(_order(<String, dynamic>{}).isEmergency, isFalse);
    expect(_order(<String, dynamic>{'orderType': 'emergency'}).isEmergency,
        isTrue);
    final VendorPendingOrder s = _order(<String, dynamic>{
      'orderType': 'schedule',
      'scheduledFor': Timestamp.fromDate(DateTime(2026, 9, 20, 18, 30)),
    });
    expect(s.isScheduled, isTrue);
  });

  test('scheduled label includes the date and 12h time', () {
    expect(vendorScheduledForLabel(DateTime(2026, 9, 20, 18, 30)),
        'Sep 20, 6:30 PM');
    expect(vendorScheduledForLabel(DateTime(2026, 1, 5, 0, 5)),
        'Jan 5, 12:05 AM');
  });

  testWidgets('emergency order shows a prominent banner', (tester) async {
    await _pump(tester, _order(<String, dynamic>{'orderType': 'emergency'}));
    expect(find.text('EMERGENCY ORDER'), findsOneWidget);
  });

  testWidgets('scheduled order shows the time it is needed', (tester) async {
    await _pump(
      tester,
      _order(<String, dynamic>{
        'orderType': 'schedule',
        'scheduledFor': Timestamp.fromDate(DateTime(2026, 9, 20, 18, 30)),
      }),
    );
    expect(find.text('SCHEDULED ORDER'), findsOneWidget);
    expect(find.textContaining('Sep 20, 6:30 PM'), findsOneWidget);
  });

  testWidgets('standard order shows nothing', (tester) async {
    await _pump(tester, _order(<String, dynamic>{}));
    expect(find.text('EMERGENCY ORDER'), findsNothing);
    expect(find.text('SCHEDULED ORDER'), findsNothing);
  });
}
