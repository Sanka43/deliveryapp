import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:mnd_delivery_app/core/constants/firebase_collections.dart';
import 'package:mnd_delivery_app/core/utils/user_facing_error.dart';
import 'package:mnd_delivery_app/features/customer/domain/entities/customer_profile.dart';
import 'package:mnd_delivery_app/features/customer/domain/profile_update_result.dart';

class CustomerProfileRepository {
  CustomerProfileRepository({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    FirebaseStorage? storage,
  })  : _auth = auth,
        _firestore = firestore,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  DocumentReference<Map<String, dynamic>> _customerDoc(String uid) =>
      _firestore.collection(FirebaseCollections.customers).doc(uid);

  Reference _profilePhotoRef(String uid) =>
      _storage.ref().child('customers/$uid/profile.jpg');

  /// Emits [null] when signed out; otherwise live profile from Auth + [customers] doc.
  Stream<CustomerProfile?> watchProfile() {
    return _auth.authStateChanges().asyncExpand((User? user) {
      if (user == null) {
        return Stream<CustomerProfile?>.value(null);
      }
      return _customerDoc(user.uid).snapshots().map(
        (DocumentSnapshot<Map<String, dynamic>> snapshot) {
          return CustomerProfile.merge(user, snapshot.data());
        },
      );
    });
  }

  /// One-shot read of Auth + [customers] doc for the signed-in user.
  Future<CustomerProfile?> fetchCurrentProfile() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      return null;
    }
    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _customerDoc(user.uid).get();
    return CustomerProfile.merge(user, snapshot.data());
  }

  /// Writes [displayName] and optional [email] to Firestore and syncs name to Firebase Auth.
  Future<ProfileUpdateResult> updateProfile({
    required String displayName,
    String? email,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      return ProfileUpdateResult.failure('You must be signed in.');
    }

    final String trimmedName = displayName.trim();
    if (trimmedName.isEmpty) {
      return ProfileUpdateResult.failure('Please enter your name.');
    }

    final String? emailTrimmed = email?.trim();
    final String? emailField =
        emailTrimmed == null || emailTrimmed.isEmpty ? null : emailTrimmed;

    final Map<String, dynamic> payload = <String, dynamic>{
      'displayName': trimmedName,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (emailField != null) {
      payload['email'] = emailField;
    } else {
      payload['email'] = FieldValue.delete();
    }

    try {
      await _customerDoc(user.uid).set(payload, SetOptions(merge: true));
    } catch (e) {
      return ProfileUpdateResult.failure(
        userFacingError(e, fallback: 'Could not save your profile.'),
      );
    }

    try {
      await user.updateDisplayName(trimmedName);
      await user.reload();
    } catch (e) {
      return ProfileUpdateResult.failure(
        userFacingError(
          e,
          fallback: 'Saved to cloud, but could not refresh sign-in name.',
        ),
      );
    }

    return const ProfileUpdateResult.success();
  }

  /// Uploads [file] to Storage and writes [photoUrl] on the customer doc + Auth.
  Future<ProfileUpdateResult> uploadProfilePhoto(File file) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      return ProfileUpdateResult.failure('You must be signed in.');
    }

    try {
      final Reference ref = _profilePhotoRef(user.uid);
      await ref.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final String downloadUrl = await ref.getDownloadURL();

      await _customerDoc(user.uid).set(
        <String, dynamic>{
          'photoUrl': downloadUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await user.updatePhotoURL(downloadUrl);
      await user.reload();
      return const ProfileUpdateResult.success();
    } catch (e) {
      return ProfileUpdateResult.failure(
        userFacingError(e, fallback: 'Could not upload profile photo.'),
      );
    }
  }

  /// Removes the Storage object and clears [photoUrl] on Firestore + Auth.
  Future<ProfileUpdateResult> removeProfilePhoto() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      return ProfileUpdateResult.failure('You must be signed in.');
    }

    try {
      try {
        await _profilePhotoRef(user.uid).delete();
      } on FirebaseException catch (e) {
        if (e.code != 'object-not-found') {
          rethrow;
        }
      }

      await _customerDoc(user.uid).set(
        <String, dynamic>{
          'photoUrl': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await user.updatePhotoURL(null);
      await user.reload();
      return const ProfileUpdateResult.success();
    } catch (e) {
      return ProfileUpdateResult.failure(
        userFacingError(e, fallback: 'Could not remove profile photo.'),
      );
    }
  }

  /// Clears profile photo, saved addresses, and the customer profile document.
  /// Caller must delete the Firebase Auth user afterwards.
  Future<void> wipeAccountOwnedData(String uid) async {
    try {
      await _profilePhotoRef(uid).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') {
        // Best-effort: continue wiping Firestore even if Storage fails.
      }
    } catch (_) {}

    final QuerySnapshot<Map<String, dynamic>> addresses =
        await _customerDoc(uid).collection('saved_addresses').get();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in addresses.docs) {
      await doc.reference.delete();
    }

    final DocumentSnapshot<Map<String, dynamic>> profile =
        await _customerDoc(uid).get();
    if (profile.exists) {
      await _customerDoc(uid).delete();
    }
  }
}
