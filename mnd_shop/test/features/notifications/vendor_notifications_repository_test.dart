import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnd_shop/core/constants/firebase_collections.dart';
import 'package:mnd_shop/features/notifications/data/vendor_notifications_repository.dart';

void main() {
  group('VendorNotificationsRepository', () {
    test('marks an owned notification as read', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final MockFirebaseAuth auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'ownerA', email: 'a@test.com'),
      );
      final VendorNotificationsRepository repo = VendorNotificationsRepository(
        firestore: firestore,
        auth: auth,
      );

      await firestore
          .collection(FirebaseCollections.vendors)
          .doc('store-1')
          .set(<String, dynamic>{'uid': 'ownerA'});
      await firestore
          .collection(FirebaseCollections.vendors)
          .doc('store-1')
          .collection(FirebaseCollections.vendorNotifications)
          .doc('n1')
          .set(<String, dynamic>{
            'title': 'New order',
            'body': 'Order arrived',
            'type': 'order_new',
            'read': false,
          });

      final String? error = await repo.markRead(
        vendorId: 'store-1',
        notificationId: 'n1',
      );

      expect(error, isNull);
      final data =
          (await firestore
                  .collection(FirebaseCollections.vendors)
                  .doc('store-1')
                  .collection(FirebaseCollections.vendorNotifications)
                  .doc('n1')
                  .get())
              .data();
      expect(data?['read'], isTrue);
      expect(data?['readAt'], isNotNull);
    });

    test('blocks notification updates for another vendor', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final MockFirebaseAuth auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'ownerA', email: 'a@test.com'),
      );
      final VendorNotificationsRepository repo = VendorNotificationsRepository(
        firestore: firestore,
        auth: auth,
      );

      await firestore
          .collection(FirebaseCollections.vendors)
          .doc('store-2')
          .set(<String, dynamic>{'uid': 'ownerB'});

      final String? error = await repo.markRead(
        vendorId: 'store-2',
        notificationId: 'n1',
      );

      expect(error, 'Not allowed.');
    });

    test('marks all owned unread notifications as read', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final MockFirebaseAuth auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'ownerA', email: 'a@test.com'),
      );
      final VendorNotificationsRepository repo = VendorNotificationsRepository(
        firestore: firestore,
        auth: auth,
      );

      await firestore
          .collection(FirebaseCollections.vendors)
          .doc('store-1')
          .set(<String, dynamic>{'uid': 'ownerA'});
      final notifications = firestore
          .collection(FirebaseCollections.vendors)
          .doc('store-1')
          .collection(FirebaseCollections.vendorNotifications);
      await notifications.doc('n1').set(<String, dynamic>{
        'title': 'One',
        'read': false,
      });
      await notifications.doc('n2').set(<String, dynamic>{
        'title': 'Two',
        'read': false,
      });

      final String? error = await repo.markAllRead('store-1');

      expect(error, isNull);
      final List<Map<String, dynamic>> marked =
          (await notifications.get()).docs
              .map((d) => d.data())
              .toList(growable: false);
      expect(marked, hasLength(2));
      expect(
        marked.every((Map<String, dynamic> d) => d['read'] == true),
        isTrue,
      );
      expect(
        marked.every((Map<String, dynamic> d) => d['readAt'] != null),
        isTrue,
      );
    });
  });
}
