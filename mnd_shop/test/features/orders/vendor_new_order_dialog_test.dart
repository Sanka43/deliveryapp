import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnd_shop/app/providers/firebase_providers.dart';
import 'package:mnd_shop/core/constants/firebase_collections.dart';
import 'package:mnd_shop/features/dashboard/domain/vendor_pending_order.dart';
import 'package:mnd_shop/features/orders/presentation/widgets/vendor_new_order_dialog.dart';

/// Seeds a `placed` order owned by the signed-in vendor so the repository's
/// ownership guard passes.
Future<FakeFirebaseFirestore> _seedOrder(String orderId) async {
  final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
  await firestore
      .collection(FirebaseCollections.vendors)
      .doc('linked-store')
      .set(<String, dynamic>{'uid': 'ownerA'});
  await firestore
      .collection(FirebaseCollections.orders)
      .doc(orderId)
      .set(<String, dynamic>{
    'vendorId': 'linked-store',
    'status': 'placed',
    'fulfillmentMode': 'delivery',
    'trackingNumber': 'MND2600091',
  });
  return firestore;
}

VendorPendingOrder _order(String id) => VendorPendingOrder(
      id: id,
      customerPhone: '+94759193986',
      itemsSummary: '1 x Cheese Koththu',
      itemLines: const <String>['1 x Cheese Koththu'],
      items: const <VendorOrderLineItem>[
        VendorOrderLineItem(
          productKey: 'cheese-koththu',
          productName: 'Cheese Koththu',
          quantity: 1,
          lineTotal: 1600,
          selectedSize: 'Chicken · Full',
          extras: <String>['Extra cheese'],
        ),
      ],
      total: 2787,
      deliveryFee: 300,
      orderCommission: 87,
      placedAtLabel: '15:39',
      itemCount: 1,
      statusKey: 'placed',
      trackingNumber: 'MND2600091',
      deliveryAddressLabel: 'X2GR+2XF, Badulla',
    );

Future<void> _pumpDialog(
  WidgetTester tester,
  FakeFirebaseFirestore firestore,
  VendorPendingOrder order,
) async {
  final MockFirebaseAuth auth = MockFirebaseAuth(
    signedIn: true,
    mockUser: MockUser(uid: 'ownerA', email: 'a@test.com'),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        firestoreProvider.overrideWithValue(firestore),
        firebaseAuthProvider.overrideWithValue(auth),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (_) => VendorNewOrderDialog(order: order),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await _settle(tester);
}

/// The popup's alert bell pulses forever, so `pumpAndSettle` would time out —
/// pump a fixed span instead, long enough for route transitions and the
/// in-flight Firestore write.
Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<String?> _statusOf(
  FakeFirebaseFirestore firestore,
  String orderId,
) async {
  final DocumentSnapshot<Map<String, dynamic>> snap = await firestore
      .collection(FirebaseCollections.orders)
      .doc(orderId)
      .get();
  return snap.data()?['status'] as String?;
}

void main() {
  testWidgets('renders order details with accept and reject actions', (
    WidgetTester tester,
  ) async {
    final FakeFirebaseFirestore firestore = await _seedOrder('order-1');
    await _pumpDialog(tester, firestore, _order('order-1'));

    expect(find.text('New order'), findsOneWidget);
    // Header shows product sales only — delivery fee and commission excluded.
    expect(find.text('Rs. 2400'), findsOneWidget);
    expect(find.text('Rs. 2787'), findsNothing);
    expect(find.text('MND2600091'), findsOneWidget);
    expect(find.text('Cheese Koththu'), findsOneWidget);
    expect(find.text('Chicken · Full'), findsOneWidget);
    expect(find.text('Extra cheese'), findsOneWidget);
    expect(find.text('Accept order'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
  });

  testWidgets('accept confirms the order and closes the popup', (
    WidgetTester tester,
  ) async {
    final FakeFirebaseFirestore firestore = await _seedOrder('order-2');
    await _pumpDialog(tester, firestore, _order('order-2'));

    await tester.tap(find.text('Accept order'));
    await _settle(tester);

    expect(await _statusOf(firestore, 'order-2'), 'confirmed');
    expect(find.text('New order'), findsNothing);
  });

  testWidgets('reject asks for confirmation before cancelling', (
    WidgetTester tester,
  ) async {
    final FakeFirebaseFirestore firestore = await _seedOrder('order-3');
    await _pumpDialog(tester, firestore, _order('order-3'));

    await tester.tap(find.text('Reject'));
    await _settle(tester);
    expect(find.text('Reject this order?'), findsOneWidget);

    // Backing out leaves the order untouched.
    await tester.tap(find.text('Keep order'));
    await _settle(tester);
    expect(await _statusOf(firestore, 'order-3'), 'placed');
    expect(find.text('New order'), findsOneWidget);

    await tester.tap(find.text('Reject'));
    await _settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Reject'));
    await _settle(tester);

    expect(await _statusOf(firestore, 'order-3'), 'cancelled');
    expect(find.text('New order'), findsNothing);
  });
}
