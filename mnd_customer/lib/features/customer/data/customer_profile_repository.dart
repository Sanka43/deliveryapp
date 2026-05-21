import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mnd_delivery_app/core/constants/firebase_collections.dart';
import 'package:mnd_delivery_app/features/customer/domain/entities/customer_profile.dart';
import 'package:mnd_delivery_app/features/customer/domain/profile_update_result.dart';

class CustomerProfileRepository {
  CustomerProfileRepository({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
  })  : _auth = auth,
        _firestore = firestore;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  /// Emits [null] when signed out; otherwise live profile from Auth + [customers] doc.
  Stream<CustomerProfile?> watchProfile() {
    return _auth.authStateChanges().asyncExpand((User? user) {
      if (user == null) {
        return Stream<CustomerProfile?>.value(null);
      }
      return _firestore
          .collection(FirebaseCollections.customers)
          .doc(user.uid)
          .snapshots()
          .map((DocumentSnapshot<Map<String, dynamic>> snapshot) {
        return CustomerProfile.merge(user, snapshot.data());
      });
    });
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
      await _firestore
          .collection(FirebaseCollections.customers)
          .doc(user.uid)
          .set(payload, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      return ProfileUpdateResult.failure(e.message ?? 'Could not save your profile.');
    } catch (e) {
      return ProfileUpdateResult.failure(e.toString());
    }

    try {
      await user.updateDisplayName(trimmedName);
      await user.reload();
    } on FirebaseAuthException catch (e) {
      return ProfileUpdateResult.failure(
        e.message ?? 'Saved to cloud, but could not refresh sign-in name.',
      );
    } catch (e) {
      return ProfileUpdateResult.failure(e.toString());
    }

    return const ProfileUpdateResult.success();
  }
}
