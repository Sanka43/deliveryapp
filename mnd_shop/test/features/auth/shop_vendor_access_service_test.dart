import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnd_shop/core/constants/firebase_collections.dart';
import 'package:mnd_shop/features/auth/data/shop_vendor_access_service.dart';

void main() {
  group('ShopVendorAccessService', () {
    test('allows vendor with vendors/{uid} profile', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await firestore.collection(FirebaseCollections.vendors).doc('vendor-1').set(
        <String, dynamic>{'uid': 'vendor-1', 'name': 'Shop'},
      );
      final ShopVendorAccessService service =
          ShopVendorAccessService(firestore: firestore);
      final MockUser user = MockUser(uid: 'vendor-1');

      final ShopVendorAccessResult result = await service.evaluate(user);

      expect(result, ShopVendorAccessResult.allowed);
    });

    test('blocks customer-only accounts', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await firestore.collection(FirebaseCollections.customers).doc('user-1').set(
        <String, dynamic>{'uid': 'user-1', 'role': 'customer'},
      );
      final ShopVendorAccessService service =
          ShopVendorAccessService(firestore: firestore);
      final MockUser user = MockUser(uid: 'user-1');

      final ShopVendorAccessResult result = await service.evaluate(user);

      expect(result, ShopVendorAccessResult.customerAccount);
    });

    test('allows new accounts without profiles for registration', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final ShopVendorAccessService service =
          ShopVendorAccessService(firestore: firestore);
      final MockUser user = MockUser(uid: 'new-vendor');

      final ShopVendorAccessResult result = await service.evaluate(user);

      expect(result, ShopVendorAccessResult.allowed);
    });

    test('blocks rider accounts', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await firestore.collection(FirebaseCollections.riders).doc('rider-1').set(
        <String, dynamic>{'uid': 'rider-1', 'fullName': 'Rider'},
      );
      final ShopVendorAccessService service =
          ShopVendorAccessService(firestore: firestore);
      final MockUser user = MockUser(uid: 'rider-1');

      final ShopVendorAccessResult result = await service.evaluate(user);

      expect(result, ShopVendorAccessResult.riderAccount);
    });

    test('blocks vendors only while deletion is pending', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await firestore.collection(FirebaseCollections.vendors).doc('vendor-1').set(
        <String, dynamic>{
          'uid': 'vendor-1',
          'name': 'Shop',
          'accountDeletionStatus': 'auth_deleted',
        },
      );
      final ShopVendorAccessService service =
          ShopVendorAccessService(firestore: firestore);
      final MockUser user = MockUser(uid: 'vendor-1');

      final ShopVendorAccessResult result = await service.evaluate(user);

      expect(result, ShopVendorAccessResult.allowed);
    });

    test('blocks vendors while deletion is still pending', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await firestore.collection(FirebaseCollections.vendors).doc('vendor-1').set(
        <String, dynamic>{
          'uid': 'vendor-1',
          'name': 'Shop',
          'accountDeletionStatus': 'pending',
        },
      );
      final ShopVendorAccessService service =
          ShopVendorAccessService(firestore: firestore);
      final MockUser user = MockUser(uid: 'vendor-1');

      final ShopVendorAccessResult result = await service.evaluate(user);

      expect(result, ShopVendorAccessResult.deletionBlocked);
    });
  });
}
