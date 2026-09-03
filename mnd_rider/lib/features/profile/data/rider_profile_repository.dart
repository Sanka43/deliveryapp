import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_rider/app/providers/firebase_providers.dart';
import 'package:mnd_rider/app/providers/rider_auth_state_provider.dart';
import 'package:mnd_rider/core/constants/firebase_collections.dart';
import 'package:mnd_rider/core/services/firebase/firebase_storage_service.dart';
import 'package:mnd_rider/features/profile/domain/rider_compliance_doc.dart';
import 'package:mnd_rider/features/profile/domain/rider_profile.dart';
import 'package:mnd_rider/features/profile/domain/rider_profile_edit_form.dart';

final Provider<RiderProfileRepository> riderProfileRepositoryProvider =
    Provider<RiderProfileRepository>((Ref ref) {
  return RiderProfileRepository(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
    storage: ref.watch(firebaseStorageServiceProvider),
  );
});

final StreamProvider<RiderProfile?> riderProfileStreamProvider =
    StreamProvider<RiderProfile?>((Ref ref) {
  final String? uid = ref.watch(riderAuthStateProvider).valueOrNull?.uid;
  if (uid == null) {
    return Stream<RiderProfile?>.value(null);
  }
  return ref.watch(riderProfileRepositoryProvider).watchProfile(uid);
});

class RiderProfileRepository {
  RiderProfileRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    required FirebaseStorageService storage,
  })  : _firestore = firestore,
        _auth = auth,
        _storage = storage;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseStorageService _storage;

  DocumentReference<Map<String, dynamic>>? get _docRef {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null) {
      return null;
    }
    return _firestore.collection(FirebaseCollections.riders).doc(uid);
  }

  Stream<RiderProfile?> watchProfile(String uid) {
    return _firestore
        .collection(FirebaseCollections.riders)
        .doc(uid)
        .snapshots()
        .map((DocumentSnapshot<Map<String, dynamic>> snap) {
      final Map<String, dynamic>? data = snap.data();
      if (!snap.exists || data == null) {
        return null;
      }
      return RiderProfile.fromDoc(snap.id, data);
    });
  }

  Future<String?> updateProfilePhotoUrl(String url) async {
    final DocumentReference<Map<String, dynamic>>? ref = _docRef;
    if (ref == null) {
      return 'Not signed in';
    }
    try {
      await ref.set(
        <String, dynamic>{
          'profilePhotoUrl': url,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> setAcceptsPassengerRides(bool value) async {
    final DocumentReference<Map<String, dynamic>>? ref = _docRef;
    if (ref == null) {
      return 'Not signed in';
    }
    try {
      await ref.set(
        <String, dynamic>{
          'acceptsPassengerRides': value,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Renews one compliance document (photo + expiry date), always re-flagging
  /// the rider for admin review — this method is compliance-only by design.
  Future<String?> renewComplianceDocument({
    required RiderComplianceDocKind kind,
    required Uint8List photoBytes,
    required DateTime expiresAt,
  }) async {
    final User? user = _auth.currentUser;
    final DocumentReference<Map<String, dynamic>>? ref = _docRef;
    if (user == null || ref == null) {
      return 'Not signed in';
    }
    try {
      final String photoUrl = switch (kind) {
        RiderComplianceDocKind.license => await _storage.uploadRiderLicensePhoto(
            riderId: user.uid,
            bytes: photoBytes,
          ),
        RiderComplianceDocKind.insurance => await _storage.uploadRiderInsurancePhoto(
            riderId: user.uid,
            bytes: photoBytes,
          ),
        RiderComplianceDocKind.revenueLicense =>
          await _storage.uploadRiderRevenueLicensePhoto(
            riderId: user.uid,
            bytes: photoBytes,
          ),
      };
      final DateTime dateOnly =
          DateTime(expiresAt.year, expiresAt.month, expiresAt.day);
      await ref.set(
        <String, dynamic>{
          kind.photoUrlField: photoUrl,
          kind.expiresAtField: Timestamp.fromDate(dateOnly),
          // Re-flag for admin review: a renewed document must not keep an
          // already-approved rider active on unverified docs.
          'status': 'pending',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      return null;
    } on FirebaseException catch (e) {
      if (e.plugin == 'firebase_storage') {
        return 'Could not upload the photo. Check connection and try again.';
      }
      return e.message ?? 'Could not save the document.';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> updateProfile({
    required RiderProfileEditForm form,
    required bool complianceChanged,
  }) async {
    final User? user = _auth.currentUser;
    final DocumentReference<Map<String, dynamic>>? ref = _docRef;
    if (user == null || ref == null) {
      return 'Not signed in';
    }

    try {
      final Map<String, dynamic> patch = <String, dynamic>{
        'fullName': form.fullName.trim(),
        'nicNumber': form.nicNumber.trim().toUpperCase(),
        'city': form.city.trim(),
        'vehicleType': form.vehicleType.firestoreValue,
        'vehicleNumber': form.vehicleNumber.trim().toUpperCase(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (form.newProfilePhotoBytes != null &&
          form.newProfilePhotoBytes!.isNotEmpty) {
        patch['profilePhotoUrl'] = await _storage.uploadRiderProfilePhoto(
          riderId: user.uid,
          bytes: form.newProfilePhotoBytes!,
        );
      }

      // vehicleType/vehicleNumber are compliance-sensitive: re-flag for admin
      // review instead of staying approved on unverified vehicle data
      // (Firestore rules require this whenever these fields actually
      // change). Document renewal (license/insurance/revenue license) is
      // handled separately by [renewComplianceDocument].
      if (complianceChanged) {
        patch['status'] = 'pending';
      }

      await ref.set(patch, SetOptions(merge: true));

      if (user.displayName != form.fullName.trim()) {
        await user.updateDisplayName(form.fullName.trim());
      }

      return null;
    } on FirebaseException catch (e) {
      if (e.plugin == 'firebase_storage') {
        return 'Could not upload photos. Check connection and try again.';
      }
      return e.message ?? 'Could not save profile.';
    } catch (e) {
      return e.toString();
    }
  }
}
