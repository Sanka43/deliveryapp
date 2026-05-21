import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/app/providers/firebase_providers.dart';
import 'package:path/path.dart' as p;

final Provider<ShopGalleryStorage> shopGalleryStorageProvider =
    Provider<ShopGalleryStorage>((Ref ref) {
  return ShopGalleryStorage(ref.watch(firebaseStorageProvider));
});

class ShopGalleryStorage {
  ShopGalleryStorage(this._storage);

  final FirebaseStorage _storage;

  /// `vendor_storefront/{storeId}/gallery_{index}.{ext}`
  Future<String> uploadShopPhoto({
    required String storeId,
    required int index,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final String ext = _storageExtension(fileName);
    final Reference ref = _storage
        .ref()
        .child('vendor_storefront')
        .child(storeId)
        .child('gallery_$index.$ext');

    final String contentType = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    final TaskSnapshot snapshot = await ref.putData(
      bytes,
      SettableMetadata(contentType: contentType),
    );
    return snapshot.ref.getDownloadURL();
  }

  Future<void> deleteShopPhotos({required String storeId, int maxCount = 4}) async {
    final String cleanStoreId = storeId.trim();
    if (cleanStoreId.isEmpty) {
      return;
    }
    for (int i = 0; i < maxCount; i++) {
      for (final String ext in <String>['jpg', 'png', 'webp']) {
        try {
          await _storage
              .ref()
              .child('vendor_storefront')
              .child(cleanStoreId)
              .child('gallery_$i.$ext')
              .delete();
        } on FirebaseException catch (e) {
          if (e.code != 'object-not-found') {
            rethrow;
          }
        }
      }
    }
  }

  static String _storageExtension(String fileName) {
    final String ext =
        p.extension(fileName).toLowerCase().replaceFirst('.', '');
    if (ext == 'png') {
      return 'png';
    }
    if (ext == 'webp') {
      return 'webp';
    }
    return 'jpg';
  }
}
