import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/app/providers/firebase_providers.dart';
import 'package:path/path.dart' as p;

final Provider<OfferImageStorage> offerImageStorageProvider =
    Provider<OfferImageStorage>((Ref ref) {
  return OfferImageStorage(ref.watch(firebaseStorageProvider));
});

class OfferImageStorage {
  OfferImageStorage(this._storage);

  final FirebaseStorage _storage;

  /// Uploads to `vendor_offers/{storeId}/{offerId}.{ext}`.
  Future<String> uploadOfferImage({
    required String storeId,
    required String offerId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final String ext = _storageExtension(fileName);
    final Reference ref = _storage
        .ref()
        .child('vendor_offers')
        .child(storeId)
        .child('$offerId.$ext');

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

  Future<void> deleteOfferImage(String imageUrl) async {
    final String url = imageUrl.trim();
    if (url.isEmpty) {
      return;
    }
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {
      // Best-effort cleanup.
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
