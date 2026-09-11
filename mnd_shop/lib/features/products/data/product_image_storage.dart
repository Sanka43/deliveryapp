import 'dart:async';
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

  // A stalled connection otherwise leaves the save button spinning with no
  // feedback and nothing to cancel — bound the upload so it fails fast with
  // a clear "try again" message instead.
  static const Duration _uploadTimeout = Duration(seconds: 45);

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
    final UploadTask task = ref.putData(
      bytes,
      SettableMetadata(contentType: contentType),
    );
    final TaskSnapshot snapshot = await task.timeout(
      _uploadTimeout,
      onTimeout: () {
        unawaited(task.cancel());
        throw TimeoutException('Product image upload timed out');
      },
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
