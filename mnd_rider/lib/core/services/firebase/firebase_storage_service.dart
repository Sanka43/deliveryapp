import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

/// Upload helpers for rider profile media.
class FirebaseStorageService {
  FirebaseStorageService(this._storage);

  final FirebaseStorage _storage;

  Future<String> uploadRiderProfilePhoto({
    required String riderId,
    required Uint8List bytes,
  }) async {
    return _uploadImage(
      path: 'riders/$riderId/profile.jpg',
      bytes: bytes,
    );
  }

  Future<String> uploadRiderLicensePhoto({
    required String riderId,
    required Uint8List bytes,
  }) async {
    return _uploadImage(
      path: 'riders/$riderId/license.jpg',
      bytes: bytes,
    );
  }

  Future<String> _uploadImage({
    required String path,
    required Uint8List bytes,
  }) async {
    final Reference ref = _storage.ref().child(path);
    final TaskSnapshot snapshot = await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    if (snapshot.state != TaskState.success) {
      throw FirebaseException(
        plugin: 'firebase_storage',
        code: 'upload-failed',
        message: 'Upload did not complete (${snapshot.state}).',
      );
    }
    return snapshot.ref.getDownloadURL();
  }

  @Deprecated('Use uploadRiderProfilePhoto')
  Future<String> uploadRiderAvatar({
    required String riderId,
    required Uint8List bytes,
  }) =>
      uploadRiderProfilePhoto(riderId: riderId, bytes: bytes);
}
