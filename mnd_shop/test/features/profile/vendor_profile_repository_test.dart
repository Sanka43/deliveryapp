import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnd_shop/core/constants/firebase_collections.dart';
import 'package:mnd_shop/features/auth/data/shop_gallery_storage.dart';
import 'package:mnd_shop/features/profile/data/vendor_profile_repository.dart';

void main() {
  group('VendorProfileRepository', () {
    test('updates profile fields and deletes blank optional whatsapp', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final MockFirebaseAuth auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'vendor-1', email: 'v@test.com'),
      );
      final VendorProfileRepository repo = VendorProfileRepository(
        firestore: firestore,
        auth: auth,
        gallery: ShopGalleryStorage(MockFirebaseStorage()),
      );

      await firestore
          .collection(FirebaseCollections.vendors)
          .doc('vendor-1')
          .set(<String, dynamic>{'whatsapp': '+94771111111'});

      final String? error = await repo.updateMyShopProfile(
        name: 'Fresh Foods',
        description: 'Lunch and dinner',
        phone: '+94770000000',
        whatsapp: '',
        addressLine: 'Main Street',
        city: 'Badulla',
        openTime: '09:00',
        closeTime: '21:00',
        closedSunday: true,
        openingNote: 'Closed on poya',
      );

      expect(error, isNull);
      final data = (await firestore
              .collection(FirebaseCollections.vendors)
              .doc('vendor-1')
              .get())
          .data();
      expect(data?['name'], 'Fresh Foods');
      expect(data?['city'], 'Badulla');
      expect(data?['whatsapp'], isNull);
      expect(data?['openingHours']['closedSunday'], isTrue);
      expect(data?['updatedAt'], isNotNull);
    });
  });
}
