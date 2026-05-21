import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mnd_rider/app/providers/firebase_providers.dart';
import 'package:mnd_rider/core/services/firebase/firebase_storage_service.dart';
import 'package:mnd_rider/features/profile/data/rider_profile_repository.dart';

enum RiderPhotoUploadTarget {
  profile,
  license,
}

final Provider<RiderAvatarStorage> riderAvatarStorageProvider =
    Provider<RiderAvatarStorage>((Ref ref) {
  return RiderAvatarStorage(
    storage: ref.watch(firebaseStorageServiceProvider),
    profileRepo: ref.watch(riderProfileRepositoryProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});

class RiderAvatarStorage {
  RiderAvatarStorage({
    required FirebaseStorageService storage,
    required RiderProfileRepository profileRepo,
    required FirebaseAuth auth,
  })  : _storage = storage,
        _profileRepo = profileRepo,
        _auth = auth;

  final FirebaseStorageService _storage;
  final RiderProfileRepository _profileRepo;
  final FirebaseAuth _auth;
  final ImagePicker _picker = ImagePicker();

  Future<({String? error, Uint8List? bytes})> pickImageBytes() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null) {
      return (error: null, bytes: null);
    }
    try {
      return (error: null, bytes: await file.readAsBytes());
    } catch (e) {
      return (error: e.toString(), bytes: null);
    }
  }

  Future<String?> uploadAndSave({
    required RiderPhotoUploadTarget target,
    required Uint8List bytes,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      return 'Not signed in';
    }
    try {
      final String url = switch (target) {
        RiderPhotoUploadTarget.profile => await _storage.uploadRiderProfilePhoto(
            riderId: user.uid,
            bytes: bytes,
          ),
        RiderPhotoUploadTarget.license => await _storage.uploadRiderLicensePhoto(
            riderId: user.uid,
            bytes: bytes,
          ),
      };
      return switch (target) {
        RiderPhotoUploadTarget.profile =>
          _profileRepo.updateProfilePhotoUrl(url),
        RiderPhotoUploadTarget.license =>
          _profileRepo.updateLicensePhotoUrl(url),
      };
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> pickAndUploadProfile() async {
    final ({String? error, Uint8List? bytes}) picked = await pickImageBytes();
    if (picked.error != null) {
      return picked.error;
    }
    if (picked.bytes == null) {
      return null;
    }
    return uploadAndSave(
      target: RiderPhotoUploadTarget.profile,
      bytes: picked.bytes!,
    );
  }
}
