import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnd_shop/core/constants/firebase_collections.dart';
import 'package:mnd_shop/features/orders/data/vendor_orders_repository.dart';

void main() {
  group('VendorOrdersRepository auth guards', () {
    test('blocks status update when order belongs to another vendor', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final MockFirebaseAuth auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'ownerA', email: 'a@test.com'),
      );
      final VendorOrdersRepository repo = VendorOrdersRepository(
        firestore: firestore,
        auth: auth,
      );

      await firestore.collection(FirebaseCollections.orders).doc('order-1').set(<String, dynamic>{
        'vendorId': 'store-other',
        'status': 'placed',
        'trackingNumber': 'MND2600001',
      });
      await firestore.collection(FirebaseCollections.vendors).doc('store-other').set(<String, dynamic>{
        'uid': 'different-user',
      });

      final String? message = await repo.updateOrderStatus(
        orderId: 'order-1',
        nextStatus: 'confirmed',
      );

      expect(message, 'You are not allowed to update this order.');
      final Map<String, dynamic>? data =
          (await firestore.collection(FirebaseCollections.orders).doc('order-1').get()).data();
      expect(data?['status'], 'placed');
    });

    test('allows status update for linked vendor owned by current user', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final MockFirebaseAuth auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'ownerA', email: 'a@test.com'),
      );
      final VendorOrdersRepository repo = VendorOrdersRepository(
        firestore: firestore,
        auth: auth,
      );

      await firestore.collection(FirebaseCollections.vendors).doc('linked-store').set(<String, dynamic>{
        'uid': 'ownerA',
      });
      await firestore.collection(FirebaseCollections.orders).doc('order-2').set(<String, dynamic>{
        'vendorId': 'linked-store',
        'status': 'placed',
        'trackingNumber': 'MND2600002',
      });

      final String? message = await repo.updateOrderStatus(
        orderId: 'order-2',
        nextStatus: 'confirmed',
      );

      expect(message, isNull);
      final Map<String, dynamic>? data =
          (await firestore.collection(FirebaseCollections.orders).doc('order-2').get()).data();
      expect(data?['status'], 'confirmed');
    });

    test('rejects invalid status values', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final MockFirebaseAuth auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'ownerA', email: 'a@test.com'),
      );
      final VendorOrdersRepository repo = VendorOrdersRepository(
        firestore: firestore,
        auth: auth,
      );

      final String? message = await repo.updateOrderStatus(
        orderId: 'order-ignored',
        nextStatus: 'hacked',
      );

      expect(message, 'Invalid order status.');
    });
  });

  group('VendorOrdersRepository order-reminder cleanup', () {
    /// Accepting a `placed` order also clears its accept-reminder inbox
    /// entries. Those docs usually don't exist, and the write against a
    /// missing one is rejected — that housekeeping failure must not be
    /// reported back as a failed accept, or the vendor sees an access error
    /// on an order the server has already confirmed.
    test('accept succeeds when no reminder notifications exist', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final MockFirebaseAuth auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'ownerA', email: 'a@test.com'),
      );
      final VendorOrdersRepository repo = VendorOrdersRepository(
        firestore: firestore,
        auth: auth,
      );

      await firestore.collection(FirebaseCollections.vendors).doc('ownerA').set(
        <String, dynamic>{'uid': 'ownerA'},
      );
      await firestore.collection(FirebaseCollections.orders).doc('order-r1').set(
        <String, dynamic>{'vendorId': 'ownerA', 'status': 'placed'},
      );

      final String? message = await repo.updateOrderStatus(
        orderId: 'order-r1',
        nextStatus: 'confirmed',
      );

      expect(message, isNull);
      final Map<String, dynamic>? data =
          (await firestore.collection(FirebaseCollections.orders).doc('order-r1').get())
              .data();
      expect(data?['status'], 'confirmed');
    });

    test('accept marks an existing reminder notification read', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final MockFirebaseAuth auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'ownerA', email: 'a@test.com'),
      );
      final VendorOrdersRepository repo = VendorOrdersRepository(
        firestore: firestore,
        auth: auth,
      );

      await firestore.collection(FirebaseCollections.vendors).doc('ownerA').set(
        <String, dynamic>{'uid': 'ownerA'},
      );
      await firestore.collection(FirebaseCollections.orders).doc('order-r2').set(
        <String, dynamic>{'vendorId': 'ownerA', 'status': 'placed'},
      );
      final DocumentReference<Map<String, dynamic>> reminder = firestore
          .collection(FirebaseCollections.vendors)
          .doc('ownerA')
          .collection(FirebaseCollections.vendorNotifications)
          .doc('order-r2_order_reminder_1');
      await reminder.set(<String, dynamic>{
        'orderId': 'order-r2',
        'type': 'order_reminder',
        'read': false,
      });

      final String? message = await repo.updateOrderStatus(
        orderId: 'order-r2',
        nextStatus: 'confirmed',
      );

      expect(message, isNull);
      expect((await reminder.get()).data()?['read'], isTrue);
    });
  });

  group('VendorOrdersRepository open/close override', () {
    test('setVendorActive writes active and openOverrideUntil', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final MockFirebaseAuth auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'ownerA', email: 'a@test.com'),
      );
      final VendorOrdersRepository repo = VendorOrdersRepository(
        firestore: firestore,
        auth: auth,
      );

      await firestore.collection(FirebaseCollections.vendors).doc('ownerA').set(
        <String, dynamic>{
          'uid': 'ownerA',
          'approvalStatus': 'approved',
          'active': true,
          'openingHours': <String, dynamic>{
            'defaultOpen': '09:00',
            'defaultClose': '21:00',
            'closedSunday': true,
          },
        },
      );

      final String? err = await repo.setVendorActive('ownerA', false);
      expect(err, isNull);

      final Map<String, dynamic>? data =
          (await firestore.collection(FirebaseCollections.vendors).doc('ownerA').get())
              .data();
      expect(data?['active'], isFalse);
      expect(data?['openOverrideUntil'], isNotNull);
    });

    test('syncVendorOpenStatusFromSchedule applies hours when override expired',
        () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final MockFirebaseAuth auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'ownerA', email: 'a@test.com'),
      );
      final VendorOrdersRepository repo = VendorOrdersRepository(
        firestore: firestore,
        auth: auth,
      );

      await firestore.collection(FirebaseCollections.vendors).doc('ownerA').set(
        <String, dynamic>{
          'uid': 'ownerA',
          'approvalStatus': 'approved',
          'active': false,
          'openingHours': <String, dynamic>{
            'defaultOpen': '00:00',
            'defaultClose': '23:59',
            'closedSunday': false,
          },
          'openOverrideUntil': Timestamp.fromDate(
            DateTime.now().toUtc().subtract(const Duration(hours: 1)),
          ),
        },
      );

      final String? err = await repo.syncVendorOpenStatusFromSchedule('ownerA');
      expect(err, isNull);

      final Map<String, dynamic>? data =
          (await firestore.collection(FirebaseCollections.vendors).doc('ownerA').get())
              .data();
      expect(data?['active'], isTrue);
      expect(data?.containsKey('openOverrideUntil') ?? true, isFalse);
    });
  });
}
