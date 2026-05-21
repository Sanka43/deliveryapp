import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnd_shop/app/providers/firebase_providers.dart';
import 'package:mnd_shop/core/constants/firebase_collections.dart';
import 'package:mnd_shop/features/auth/data/shop_gallery_storage.dart';
import 'package:mnd_shop/features/auth/data/shop_registration_repository.dart';
import 'package:mnd_shop/features/auth/domain/shop_registration_payload.dart';

class _ThrowingGalleryStorage extends ShopGalleryStorage {
  _ThrowingGalleryStorage(super.storage);

  final List<String> deletedStoreIds = <String>[];

  @override
  Future<String> uploadShopPhoto({
    required String storeId,
    required int index,
    required Uint8List bytes,
    required String fileName,
  }) async {
    throw FirebaseException(
      plugin: 'test',
      code: 'unavailable',
      message: 'simulated upload failure',
    );
  }

  @override
  Future<void> deleteShopPhotos({required String storeId, int maxCount = 4}) async {
    deletedStoreIds.add(storeId);
  }
}

void main() {
  test('rolls back partial registration when gallery upload fails', () async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final MockFirebaseAuth auth = MockFirebaseAuth();
    final _ThrowingGalleryStorage gallery = _ThrowingGalleryStorage(MockFirebaseStorage());

    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        firestoreProvider.overrideWithValue(firestore),
        firebaseAuthProvider.overrideWithValue(auth),
        firebaseStorageProvider.overrideWithValue(MockFirebaseStorage()),
        shopGalleryStorageProvider.overrideWithValue(gallery),
      ],
    );
    addTearDown(container.dispose);

    final ShopRegistrationRepository repo = container.read(shopRegistrationRepositoryProvider);
    final ShopRegistrationResult result = await repo.registerNewShop(
      ShopRegistrationPayload(
        shopDisplayName: 'Demo Shop',
        email: 'demo@test.com',
        password: '123456',
        phone: '+94770000000',
        whatsapp: '+94770000000',
        addressLine: 'No 1, Main Street',
        city: 'Colombo',
        latitude: 6.9271,
        longitude: 79.8612,
        shopDescription: 'A demo test shop description',
        categoryLabel: 'Food',
        shopTypeLabel: 'Restaurant',
        openTime: '09:00',
        closeTime: '21:00',
        closedSunday: false,
        openingHoursExtraNote: '',
        wageKitchenNotes: '',
        wageCounterNotes: '',
        wageDeliveryNotes: '',
        shopPhotos: <Uint8List?>[Uint8List.fromList(<int>[1, 2, 3])],
      ),
    );

    expect(result.isSuccess, isFalse);
    expect(result.errorMessage, 'Service temporarily unavailable. Please try again.');
    expect(gallery.deletedStoreIds, hasLength(1));

    final String rolledBackStoreId = gallery.deletedStoreIds.first;
    final bool vendorDocExists =
        (await firestore.collection(FirebaseCollections.vendors).doc(rolledBackStoreId).get()).exists;
    expect(vendorDocExists, isFalse);
  });
}
