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
    String side = 'front',
  }) async {
    final String fileName =
        side == 'front' ? 'license.jpg' : 'license_$side.jpg';
    return _uploadImage(
      path: 'riders/$riderId/$fileName',
      bytes: bytes,
    );
  }

  Future<String> uploadRiderVehiclePhoto({
    required String riderId,
    required Uint8List bytes,
    String side = 'front',
  }) async {
    final String fileName =
        side == 'front' ? 'vehicle.jpg' : 'vehicle_$side.jpg';
    return _uploadImage(
      path: 'riders/$riderId/$fileName',
      bytes: bytes,
    );
  }

  Future<String> uploadRiderInsurancePhoto({
    required String riderId,
    required Uint8List bytes,
  }) async {
    return _uploadImage(
      path: 'riders/$riderId/insurance.jpg',
      bytes: bytes,
    );
  }

  Future<String> uploadRiderRevenueLicensePhoto({
    required String riderId,
    required Uint8List bytes,
  }) async {
    return _uploadImage(
      path: 'riders/$riderId/revenue_license.jpg',
      bytes: bytes,
    );
  }

  /// Proof of a cash handover (e.g. a bank deposit slip) attached when the
  /// rider requests a settlement. Timestamped rather than overwriting a
  /// fixed filename — unlike the profile/compliance photos above, a rider
  /// hands over cash repeatedly and each handover's evidence should survive
  /// the next one.
  Future<String> uploadRiderCashSettlementReference({
    required String riderId,
    required Uint8List bytes,
  }) async {
    return _uploadImage(
      path:
          'riders/$riderId/cash_settlements/${DateTime.now().millisecondsSinceEpoch}.jpg',
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
