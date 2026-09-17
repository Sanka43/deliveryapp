import 'dart:async';
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

  // A stalled connection otherwise leaves the save button spinning with no
  // feedback and nothing to cancel — bound the upload so it fails fast with
  // a clear "try again" message instead. Matches ProductImageStorage.
  static const Duration _uploadTimeout = Duration(seconds: 45);

  /// Uploads to `vendor_offers/{storeId}/{offerId}_{uploadedAtMs}.{ext}` —
  /// a fresh object per upload rather than a fixed `{offerId}.{ext}` path,
  /// so a re-upload never overwrites the still-referenced old image in
  /// place and the old one can be deleted only after this upload succeeds.
  Future<String> uploadOfferImage({
    required String storeId,
    required String offerId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final String ext = _storageExtension(fileName);
    final int uploadedAtMs = DateTime.now().millisecondsSinceEpoch;
    final Reference ref = _storage
        .ref()
        .child('vendor_offers')
        .child(storeId)
        .child('${offerId}_$uploadedAtMs.$ext');

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
        throw TimeoutException('Offer image upload timed out');
      },
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
