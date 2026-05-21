import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_rider/app/providers/firebase_providers.dart';
import 'package:mnd_rider/core/constants/firebase_collections.dart';
import 'package:mnd_rider/core/services/firebase/firebase_storage_service.dart';
import 'package:mnd_rider/features/auth/data/rider_registration_validator.dart';
import 'package:mnd_rider/features/auth/domain/rider_profile_document.dart';
import 'package:mnd_rider/features/auth/domain/rider_registration_form.dart';

const String kTemporaryOtpVerificationId = '__MND_RIDER_TEMP_OTP__';
const String kTemporaryOtpCode = '123456';

final Provider<RiderAuthRepository> riderAuthRepositoryProvider =
    Provider<RiderAuthRepository>((Ref ref) {
  return RiderAuthRepository(
    auth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firestoreProvider),
    storage: ref.watch(firebaseStorageServiceProvider),
  );
});

class RiderAuthRepository {
  RiderAuthRepository({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    required FirebaseStorageService storage,
  })  : _auth = auth,
        _firestore = firestore,
        _storage = storage;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorageService _storage;

  CollectionReference<Map<String, dynamic>> get _riders =>
      _firestore.collection(FirebaseCollections.riders);

  Future<RiderProfileDocument?> fetchRiderProfile(String uid) async {
    final DocumentSnapshot<Map<String, dynamic>> snap = await _riders.doc(uid).get();
    if (!snap.exists || snap.data() == null) {
      return null;
    }
    return RiderProfileDocument.fromFirestore(snap.id, snap.data()!);
  }

  Stream<RiderProfileDocument?> watchRiderProfile(String uid) {
    return _riders.doc(uid).snapshots().map(
      (DocumentSnapshot<Map<String, dynamic>> snap) {
        if (!snap.exists || snap.data() == null) {
          return null;
        }
        return RiderProfileDocument.fromFirestore(snap.id, snap.data()!);
      },
    );
  }

  Future<String> sendPhoneOtp(String e164Phone) async {
    final Completer<String> completer = Completer<String>();

    await _auth.verifyPhoneNumber(
      phoneNumber: e164Phone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          await _auth.signInWithCredential(credential);
          if (!completer.isCompleted) {
            completer.complete('');
          }
        } catch (e) {
          if (!completer.isCompleted) {
            completer.completeError(e);
          }
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!completer.isCompleted) {
          completer.complete(verificationId);
        }
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        if (!completer.isCompleted) {
          completer.complete(verificationId);
        }
      },
    );

    return completer.future;
  }

  Future<void> verifyPhoneOtp({
    required String verificationId,
    required String smsCode,
    required String e164Phone,
  }) async {
    if (kDebugMode && verificationId == kTemporaryOtpVerificationId) {
      if (smsCode.trim() != kTemporaryOtpCode) {
        throw FirebaseAuthException(code: 'invalid-verification-code');
      }
      await _signInWithDebugPhone(e164Phone);
      return;
    }

    if (verificationId.isEmpty) {
      return;
    }

    final PhoneAuthCredential credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode.trim(),
    );
    await _auth.signInWithCredential(credential);
  }

  Future<void> _signInWithDebugPhone(String e164Phone) async {
    final String email = authEmailForPhone(e164Phone);
    const String password = 'MndRiderTempOtp123456!';
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        await _auth.createUserWithEmailAndPassword(email: email, password: password);
      } else {
        rethrow;
      }
    }
  }

  Future<void> signInWithPhonePassword({
    required String e164Phone,
    required String password,
  }) async {
    final String email = authEmailForPhone(e164Phone);
    final String trimmedPassword = password.trim();
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: trimmedPassword,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code != 'invalid-credential' && e.code != 'wrong-password') {
        rethrow;
      }
      // Legacy OTP/dev accounts used a fixed temp password — recover once.
      const String legacyTempPassword = 'MndRiderTempOtp123456!';
      try {
        final UserCredential cred = await _auth.signInWithEmailAndPassword(
          email: email,
          password: legacyTempPassword,
        );
        await cred.user?.updatePassword(trimmedPassword);
      } on FirebaseAuthException {
        rethrow;
      }
    }
  }

  Future<void> registerRider(RiderRegistrationForm form) async {
    final String e164 = normalizeSriLankaPhone('+94', form.phone);
    final String email = authEmailForPhone(e164);
    final User? current = _auth.currentUser;

    User user = await _ensureEmailPasswordAccount(
      email: email,
      password: form.password.trim(),
      existingUser: current,
    );
    await user.updateDisplayName(form.fullName.trim());

    // Ensure Storage sees a fresh auth token after phone link / email sign-in.
    await user.getIdToken(true);

    final String profileUrl = await _storage.uploadRiderProfilePhoto(
      riderId: user.uid,
      bytes: form.profilePhotoBytes!,
    );
    final String licenseUrl = await _storage.uploadRiderLicensePhoto(
      riderId: user.uid,
      bytes: form.licensePhotoBytes!,
    );

    await _riders.doc(user.uid).set(<String, dynamic>{
      'uid': user.uid,
      'fullName': form.fullName.trim(),
      'phone': e164,
      'nicNumber': form.nicNumber.trim().toUpperCase(),
      'profilePhotoUrl': profileUrl,
      'licensePhotoUrl': licenseUrl,
      'vehicleType': form.vehicleType!.firestoreValue,
      'vehicleNumber': form.vehicleNumber.trim().toUpperCase(),
      'city': form.city.trim(),
      'email': email,
      'role': 'rider',
      'status': 'pending',
      'online': false,
      'registrationComplete': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Ensures Firebase Auth has email/password for this phone, with the chosen password.
  Future<User> _ensureEmailPasswordAccount({
    required String email,
    required String password,
    required User? existingUser,
  }) async {
    final User? current = existingUser ?? _auth.currentUser;

    if (current != null &&
        current.email != null &&
        current.email!.toLowerCase() == email.toLowerCase()) {
      await current.updatePassword(password);
      return current;
    }

    if (current != null) {
      try {
        final UserCredential linked = await current.linkWithCredential(
          EmailAuthProvider.credential(email: email, password: password),
        );
        final User? linkedUser = linked.user;
        if (linkedUser != null) {
          return linkedUser;
        }
      } on FirebaseAuthException catch (e) {
        if (e.code != 'email-already-in-use' &&
            e.code != 'credential-already-in-use' &&
            e.code != 'provider-already-linked') {
          rethrow;
        }
      }
    }

    try {
      final UserCredential created = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final User? user = created.user;
      if (user == null) {
        throw FirebaseAuthException(code: 'user-not-created');
      }
      return user;
    } on FirebaseAuthException catch (e) {
      if (e.code != 'email-already-in-use') {
        rethrow;
      }
    }

    await _auth.signOut();

    try {
      final UserCredential signedIn = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final User? user = signedIn.user;
      if (user != null) {
        return user;
      }
    } on FirebaseAuthException catch (e) {
      if (e.code != 'wrong-password' && e.code != 'invalid-credential') {
        rethrow;
      }
    }

    const String legacyTempPassword = 'MndRiderTempOtp123456!';
    final UserCredential legacy = await _auth.signInWithEmailAndPassword(
      email: email,
      password: legacyTempPassword,
    );
    final User? legacyUser = legacy.user;
    if (legacyUser == null) {
      throw FirebaseAuthException(code: 'wrong-password');
    }
    await legacyUser.updatePassword(password);
    return legacyUser;
  }

  Future<void> signOut() => _auth.signOut();

  static String mapAuthError(Object e) {
    if (e is FirebaseException && e.plugin == 'firebase_storage') {
      switch (e.code) {
        case 'unauthorized':
        case 'permission-denied':
          return 'Photo upload is blocked. Deploy Firebase Storage rules for riders, then try again.';
        case 'canceled':
          return 'Photo upload was cancelled. Check your connection and try again.';
        case 'retry-limit-exceeded':
          return 'Upload timed out. Use Wi‑Fi and try again.';
        default:
          return e.message ?? 'Could not upload photos. Please try again.';
      }
    }
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-phone-number':
          return 'This phone number is not valid.';
        case 'invalid-verification-code':
          return 'Invalid or expired OTP. Try again.';
        case 'too-many-requests':
          return 'Too many attempts. Please wait and try again.';
        case 'email-already-in-use':
          return 'This phone is already registered. Try signing in.';
        case 'weak-password':
          return 'Choose a stronger password (8+ characters).';
        case 'wrong-password':
        case 'invalid-credential':
          return 'Incorrect password for this phone number.';
        case 'user-not-found':
          return 'No account for this number. Register first or sign in with OTP.';
        case 'invalid-email':
          return 'Invalid phone number format.';
        case 'operation-not-allowed':
          return 'Sign-in method is not enabled in Firebase Console.';
        default:
          return e.message ?? 'Authentication failed.';
      }
    }
    return e.toString();
  }
}
