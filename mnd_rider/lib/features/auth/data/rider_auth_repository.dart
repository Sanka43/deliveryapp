import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_rider/app/providers/firebase_providers.dart';
import 'package:mnd_rider/core/constants/firebase_collections.dart';
import 'package:mnd_rider/core/services/firebase/firebase_storage_service.dart';
import 'package:mnd_rider/core/utils/user_facing_error.dart';
import 'package:mnd_rider/features/auth/data/rider_registration_validator.dart';
import 'package:mnd_rider/features/auth/domain/rider_profile_document.dart';
import 'package:mnd_rider/features/auth/domain/rider_registration_form.dart';

final Provider<RiderAuthRepository> riderAuthRepositoryProvider =
    Provider<RiderAuthRepository>((Ref ref) {
  return RiderAuthRepository(
    auth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firestoreProvider),
    storage: ref.watch(firebaseStorageServiceProvider),
    functions: ref.watch(firebaseFunctionsProvider),
  );
});

class RiderAuthRepository {
  RiderAuthRepository({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    required FirebaseStorageService storage,
    required FirebaseFunctions functions,
  })  : _auth = auth,
        _firestore = firestore,
        _storage = storage,
        _functions = functions;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorageService _storage;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _riders =>
      _firestore.collection(FirebaseCollections.riders);

  User? get currentUser => _auth.currentUser;

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

  /// Requests an OTP via SMSlenz Cloud Function. Returns server `sessionId`.
  ///
  /// [purpose]: `rider_login` (must already be registered) or `rider_register`.
  Future<String> sendPhoneOtp(
    String e164Phone, {
    required String purpose,
  }) async {
    final HttpsCallableResult<dynamic> result = await _functions
        .httpsCallable('requestPhoneOtp')
        .call(<String, dynamic>{
      'phone': e164Phone,
      'purpose': purpose,
    });
    final Object? data = result.data;
    if (data is Map) {
      final Object? sessionId = data['sessionId'];
      if (sessionId is String && sessionId.isNotEmpty) {
        return sessionId;
      }
    }
    throw FirebaseAuthException(
      code: 'internal-error',
      message: 'Could not start phone verification. Try again.',
    );
  }

  Future<void> verifyPhoneOtp({
    required String verificationId,
    required String smsCode,
    required String e164Phone,
  }) async {
    if (verificationId.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-verification-id',
        message: 'Phone verification expired. Request a new OTP.',
      );
    }

    final HttpsCallableResult<dynamic> result = await _functions
        .httpsCallable('verifyPhoneOtp')
        .call(<String, dynamic>{
      'phone': e164Phone,
      'otp': smsCode.trim(),
      'sessionId': verificationId,
    });

    final Object? data = result.data;
    String? customToken;
    if (data is Map) {
      final Object? raw = data['customToken'];
      if (raw is String && raw.isNotEmpty) {
        customToken = raw;
      }
    }
    if (customToken == null) {
      throw FirebaseAuthException(
        code: 'internal-error',
        message: 'Could not complete phone sign-in. Try again.',
      );
    }

    await _auth.signInWithCustomToken(customToken);
    await _auth.currentUser?.reload();
    if (!isPhoneVerifiedFor(e164Phone)) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await _auth.currentUser?.reload();
    }
    // Custom token already signed the rider in. Do not throw phone-mismatch
    // after the OTP was consumed — phoneNumber can lag on custom tokens.
    if (_auth.currentUser == null) {
      throw FirebaseAuthException(
        code: 'internal-error',
        message: 'Could not complete phone sign-in. Try again.',
      );
    }
  }

  /// True when the signed-in Auth user has completed phone OTP for [e164Phone].
  bool isPhoneVerifiedFor(String e164Phone) {
    final String? verified = _auth.currentUser?.phoneNumber?.trim();
    if (verified == null || verified.isEmpty) {
      return false;
    }
    return verified == e164Phone.trim();
  }

  Future<void> registerRider(RiderRegistrationForm form) async {
    final String e164 = normalizeSriLankaPhone('+94', form.phone);
    final User? current = _auth.currentUser;
    if (current == null) {
      throw FirebaseAuthException(
        code: 'phone-not-verified',
        message: 'Verify your phone with OTP before registering.',
      );
    }
    // Custom-token sign-in can leave phoneNumber empty briefly; only reject
    // when Auth already has a *different* number.
    if (isPhoneVerifiedFor(e164) == false &&
        (current.phoneNumber?.trim().isNotEmpty ?? false)) {
      throw FirebaseAuthException(
        code: 'phone-not-verified',
        message: 'Verify your phone with OTP before registering.',
      );
    }

    final User user = current;

    final RiderProfileDocument? existing = await fetchRiderProfile(user.uid);
    if (existing != null && existing.isRegistrationComplete) {
      throw FirebaseAuthException(
        code: 'already-exists',
        message: 'This number is already registered. Sign in instead.',
      );
    }

    await user.updateDisplayName(form.fullName.trim());

    // Ensure Storage sees a fresh auth token after phone OTP sign-in.
    await user.getIdToken(true);

    final String profileUrl = await _storage.uploadRiderProfilePhoto(
      riderId: user.uid,
      bytes: form.profilePhotoBytes!,
    );
    final String licenseUrl = await _storage.uploadRiderLicensePhoto(
      riderId: user.uid,
      bytes: form.licensePhotoBytes!,
    );
    final Map<String, String> vehiclePhotoUrls = <String, String>{};
    for (final RiderVehiclePhotoSide side in RiderVehiclePhotoSide.values) {
      vehiclePhotoUrls[side.firestoreKey] = await _storage.uploadRiderVehiclePhoto(
        riderId: user.uid,
        bytes: form.vehiclePhotoBytesFor(side)!,
        side: side.firestoreKey,
      );
    }
    final String vehicleUrl = vehiclePhotoUrls[RiderVehiclePhotoSide.front.firestoreKey]!;
    final String insuranceUrl = await _storage.uploadRiderInsurancePhoto(
      riderId: user.uid,
      bytes: form.insurancePhotoBytes!,
    );
    final String revenueLicenseUrl =
        await _storage.uploadRiderRevenueLicensePhoto(
      riderId: user.uid,
      bytes: form.revenueLicensePhotoBytes!,
    );

    // Fresh ID token so Firestore rules can see phone_number / phoneVerified.
    await user.getIdToken(true);

    await _riders.doc(user.uid).set(<String, dynamic>{
      'uid': user.uid,
      'fullName': form.fullName.trim(),
      'phone': e164,
      'nicNumber': form.nicNumber.trim().toUpperCase(),
      'profilePhotoUrl': profileUrl,
      'licensePhotoUrl': licenseUrl,
      'licenseExpiresAt': Timestamp.fromDate(
        DateTime(
          form.licenseExpiresAt!.year,
          form.licenseExpiresAt!.month,
          form.licenseExpiresAt!.day,
        ),
      ),
      'vehiclePhotoUrl': vehicleUrl,
      'vehiclePhotos': vehiclePhotoUrls,
      'insurancePhotoUrl': insuranceUrl,
      'insuranceExpiresAt': Timestamp.fromDate(
        DateTime(
          form.insuranceExpiresAt!.year,
          form.insuranceExpiresAt!.month,
          form.insuranceExpiresAt!.day,
        ),
      ),
      'revenueLicensePhotoUrl': revenueLicenseUrl,
      'revenueLicenseExpiresAt': Timestamp.fromDate(
        DateTime(
          form.revenueLicenseExpiresAt!.year,
          form.revenueLicenseExpiresAt!.month,
          form.revenueLicenseExpiresAt!.day,
        ),
      ),
      'vehicleType': form.vehicleType!.firestoreValue,
      'vehicleNumber': form.vehicleNumber.trim().toUpperCase(),
      'city': form.city.trim(),
      'email': user.email?.trim() ?? '',
      'role': 'rider',
      'status': existing != null && existing.isApprovedToDrive
          ? existing.status
          : 'pending',
      'online': false,
      'registrationComplete': true,
      'phoneVerified': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> signOut() => _auth.signOut();

  static String mapAuthError(Object e) {
    if (e is FirebaseFunctionsException) {
      switch (e.code) {
        case 'invalid-argument':
          return e.message?.trim().isNotEmpty == true
              ? e.message!.trim()
              : 'This phone number is not valid.';
        case 'permission-denied':
          return 'Invalid or expired OTP. Try again.';
        case 'not-found':
          return e.message?.trim().isNotEmpty == true
              ? e.message!.trim()
              : 'Still not registered';
        case 'already-exists':
          return e.message?.trim().isNotEmpty == true
              ? e.message!.trim()
              : 'This number is already registered. Sign in instead.';
        case 'failed-precondition':
        case 'deadline-exceeded':
          return e.message?.trim().isNotEmpty == true
              ? e.message!.trim()
              : 'Phone verification expired. Request a new OTP.';
        case 'resource-exhausted':
          return e.message?.trim().isNotEmpty == true
              ? e.message!.trim()
              : 'Too many attempts. Please wait and try again.';
        case 'unavailable':
          return e.message?.trim().isNotEmpty == true
              ? e.message!.trim()
              : 'Could not send verification SMS. Try again.';
        default:
          return e.message?.trim().isNotEmpty == true
              ? e.message!.trim()
              : 'Authentication failed.';
      }
    }
    if (e is FirebaseException && e.plugin == 'firebase_storage') {
      switch (e.code) {
        case 'unauthorized':
        case 'permission-denied':
          return 'Could not upload photos. Try again or contact support.';
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
        case 'invalid-verification-id':
          return 'Phone verification expired. Request a new OTP.';
        case 'phone-mismatch':
          return 'Verified phone does not match the number you entered.';
        case 'too-many-requests':
          return 'Too many attempts. Please wait and try again.';
        case 'phone-not-verified':
          return 'Verify your phone with OTP before registering.';
        case 'session-mismatch':
          return 'Another phone session is active. Sign out, then try again.';
        case 'timeout':
          return 'Phone verification timed out. Check your connection and try again.';
        case 'invalid-custom-token':
        case 'custom-token-mismatch':
          return 'Sign-in failed. Request a new OTP and try again.';
        case 'operation-not-allowed':
          return 'Sign-in is temporarily unavailable. Try again later.';
        case 'already-exists':
          return 'This number is already registered. Sign in instead.';
        default:
          return e.message ?? 'Authentication failed.';
      }
    }
    if (e is FirebaseException && e.plugin == 'cloud_firestore') {
      switch (e.code) {
        case 'permission-denied':
          return 'Could not save your rider profile. Sign in again and retry.';
        default:
          return e.message ?? 'Could not save your rider profile. Please try again.';
      }
    }
    return userFacingError(e, fallback: 'Authentication failed.');
  }
}
