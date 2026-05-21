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
}
