import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/app/providers/firebase_providers.dart';
import 'package:path/path.dart' as p;

final Provider<ProductImageStorage> productImageStorageProvider =
    Provider<ProductImageStorage>((Ref ref) {
  return ProductImageStorage(ref.watch(firebaseStorageProvider));
});

class ProductImageStorage {
  ProductImageStorage(this._storage);

  final FirebaseStorage _storage;

  /// Uploads image bytes to `vendor_products/{storeId}/{productId}.{ext}`.
  Future<String> uploadProductImage({
    required String storeId,
    required String productId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final String ext = _storageExtension(fileName);
    final Reference ref = _storage
        .ref()
        .child('vendor_products')
        .child(storeId)
        .child('$productId.$ext');

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
