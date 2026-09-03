import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/app/providers/firebase_providers.dart';
import 'package:mnd_delivery_app/core/constants/firebase_collections.dart';
import 'package:mnd_delivery_app/core/services/fcm_token_repository.dart';
import 'package:mnd_delivery_app/features/customer/data/customer_profile_repository.dart';
import 'package:mnd_delivery_app/features/customer/domain/entities/customer_profile.dart';

class PhoneAuthState {
  const PhoneAuthState({
    this.isLoading = false,
    this.errorMessage,
    this.pendingPhoneNumber,
  });

  final bool isLoading;
  final String? errorMessage;
  final String? pendingPhoneNumber;

  bool get hasPendingOtp =>
      pendingPhoneNumber != null && pendingPhoneNumber!.isNotEmpty;

  PhoneAuthState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? pendingPhoneNumber,
    bool clearError = false,
    bool clearPendingPhone = false,
  }) {
    return PhoneAuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      pendingPhoneNumber: clearPendingPhone
          ? null
          : (pendingPhoneNumber ?? this.pendingPhoneNumber),
    );
  }
}

final StateNotifierProvider<PhoneAuthController, PhoneAuthState>
    phoneAuthControllerProvider =
    StateNotifierProvider<PhoneAuthController, PhoneAuthState>(
  (Ref ref) {
    return PhoneAuthController(
      ref.read(firebaseAuthProvider),
      ref.read(firestoreProvider),
      ref.read(firebaseMessagingProvider),
      FirebaseFunctions.instanceFor(region: 'asia-south1'),
    );
  },
);

class PhoneAuthController extends StateNotifier<PhoneAuthState> {
  PhoneAuthController(
    this._auth,
    this._firestore,
    this._messaging,
    this._functions,
  ) : super(const PhoneAuthState());

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseMessaging _messaging;
  final FirebaseFunctions _functions;

  /// Sync locks — Riverpod isLoading alone can race on double-taps.
  bool _sendInFlight = false;
  bool _verifyInFlight = false;

  /// Server session id from [requestPhoneOtp] (memory only).
  String? _sessionId;

  /// Monotonic id so a slow older send cannot overwrite a newer session.
  int _sendGeneration = 0;

  String? get pendingVerificationId => _sessionId;

  static String _otpSendErrorMessage(Object e) {
    if (e is FirebaseFunctionsException) {
      debugPrint('OTP send error code=${e.code} message=${e.message}');
      switch (e.code) {
        case 'invalid-argument':
          return e.message?.trim().isNotEmpty == true
              ? e.message!.trim()
              : 'This phone number format is not valid.';
        case 'resource-exhausted':
          return e.message?.trim().isNotEmpty == true
              ? e.message!.trim()
              : 'Too many attempts. Please try again later.';
        case 'unavailable':
        case 'failed-precondition':
          return e.message?.trim().isNotEmpty == true
              ? e.message!.trim()
              : 'SMS could not be sent right now. Please try again later.';
        case 'deadline-exceeded':
          return 'Request timed out. Check your connection and try again.';
        default:
          return e.message?.trim().isNotEmpty == true
              ? e.message!.trim()
              : 'Could not send verification code. Please try again.';
      }
    }
    if (e is FirebaseAuthException) {
      debugPrint('OTP send auth error code=${e.code} message=${e.message}');
      if (e.code == 'network-request-failed') {
        return 'Network error. Check your connection and try again.';
      }
    }
    return 'Could not send verification code. Please try again.';
  }

  static String _otpVerifyErrorMessage(Object e) {
    if (e is FirebaseFunctionsException) {
      debugPrint('OTP verify error code=${e.code} message=${e.message}');
      switch (e.code) {
        case 'permission-denied':
          return 'Wrong code. Check the latest SMS and try again.';
        case 'not-found':
        case 'failed-precondition':
        case 'deadline-exceeded':
          return e.message?.trim().isNotEmpty == true
              ? e.message!.trim()
              : 'This code is no longer valid. Tap Resend for a new one.';
        case 'resource-exhausted':
          return e.message?.trim().isNotEmpty == true
              ? e.message!.trim()
              : 'Too many attempts. Please try again later.';
        case 'invalid-argument':
          return e.message?.trim().isNotEmpty == true
              ? e.message!.trim()
              : 'Enter the full 6-digit code';
        default:
          return e.message?.trim().isNotEmpty == true
              ? e.message!.trim()
              : 'Could not verify the code. Tap Resend and use the newest SMS.';
      }
    }
    if (e is FirebaseAuthException) {
      debugPrint('OTP verify auth error code=${e.code} message=${e.message}');
      switch (e.code) {
        case 'invalid-custom-token':
        case 'custom-token-mismatch':
          return 'Sign-in failed. Tap Resend and try again.';
        case 'network-request-failed':
          return 'Network error. Check your connection and try again.';
        default:
          return 'Could not verify the code. Tap Verify again or Resend.';
      }
    }
    return 'OTP verification failed. Please try again.';
  }

  Future<String?> sendOtp(
    String phoneNumber, {
    bool forceResend = false,
  }) async {
    if (_sendInFlight || state.isLoading) {
      return null;
    }
    _sendInFlight = true;
    final int generation = ++_sendGeneration;

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      pendingPhoneNumber: phoneNumber,
    );

    try {
      final HttpsCallableResult<dynamic> result = await _functions
          .httpsCallable('requestPhoneOtp')
          .call(<String, dynamic>{
        'phone': phoneNumber,
        'purpose': forceResend ? 'customer_resend' : 'customer_login',
      });

      if (generation != _sendGeneration) {
        return null;
      }

      final Object? data = result.data;
      String? sessionId;
      if (data is Map) {
        final Object? raw = data['sessionId'];
        if (raw is String && raw.isNotEmpty) {
          sessionId = raw;
        }
      }
      if (sessionId == null || sessionId.isEmpty) {
        throw StateError('requestPhoneOtp missing sessionId');
      }

      _sessionId = sessionId;
      state = state.copyWith(
        isLoading: false,
        clearError: true,
        pendingPhoneNumber: phoneNumber,
      );
      return sessionId;
    } catch (e) {
      debugPrint('OTP send failed: $e');
      if (generation == _sendGeneration) {
        _sessionId = null;
        state = state.copyWith(
          isLoading: false,
          errorMessage: _otpSendErrorMessage(e),
          clearPendingPhone: true,
        );
      }
      return null;
    } finally {
      if (generation == _sendGeneration) {
        _sendInFlight = false;
      }
    }
  }

  Future<bool> verifyOtp({
    required String smsCode,
    String? verificationId,
  }) async {
    if (_verifyInFlight || state.isLoading) {
      return false;
    }
    _verifyInFlight = true;
    state = state.copyWith(isLoading: true, clearError: true);

    final String code = smsCode.replaceAll(RegExp(r'\D'), '');
    if (code.length != 6) {
      _verifyInFlight = false;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Enter the full 6-digit code',
      );
      return false;
    }

    final String? phone = state.pendingPhoneNumber;
    if (phone == null || phone.isEmpty) {
      _verifyInFlight = false;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Session expired. Go back and request a new OTP.',
      );
      return false;
    }

    final String? sessionId = _sessionId ?? verificationId;
    if (sessionId == null || sessionId.isEmpty) {
      _verifyInFlight = false;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Session expired. Go back and request a new OTP.',
      );
      return false;
    }

    try {
      final HttpsCallableResult<dynamic> result = await _functions
          .httpsCallable('verifyPhoneOtp')
          .call(<String, dynamic>{
        'phone': phone,
        'otp': code,
        'sessionId': sessionId,
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
        throw StateError('verifyPhoneOtp missing customToken');
      }

      final UserCredential userCredential =
          await _auth.signInWithCustomToken(customToken);

      try {
        await _ensureUserProfile(
          userCredential.user,
          fallbackPhoneNumber: phone,
        );
      } catch (e, st) {
        // Sign-in already succeeded; profile sync is best-effort.
        debugPrint('OTP profile sync failed after sign-in: $e\n$st');
      }

      _sessionId = null;
      state = state.copyWith(
        isLoading: false,
        clearError: true,
        clearPendingPhone: true,
      );
      return true;
    } catch (e, st) {
      debugPrint('OTP verify failed: $e\n$st');
      final bool sessionDead = e is FirebaseFunctionsException &&
          (e.code == 'not-found' ||
              e.code == 'deadline-exceeded' ||
              e.code == 'failed-precondition');
      if (sessionDead) {
        _sessionId = null;
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: _otpVerifyErrorMessage(e),
      );
      return false;
    } finally {
      _verifyInFlight = false;
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Creates or merges [customers]/{uid}, syncs FCM, then returns the merged profile.
  Future<CustomerProfile?> _ensureUserProfile(
    User? user, {
    String? fallbackPhoneNumber,
  }) async {
    if (user == null) {
      return null;
    }

    final DocumentReference<Map<String, dynamic>> userRef =
        _firestore.collection(FirebaseCollections.customers).doc(user.uid);
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await userRef.get();

    if (!snapshot.exists) {
      await userRef.set(<String, dynamic>{
        'uid': user.uid,
        'role': 'customer',
        'displayName': user.displayName,
        'email': user.email,
        'phoneNumber': user.phoneNumber ?? fallbackPhoneNumber,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await userRef.set(
        <String, dynamic>{
          'displayName': user.displayName,
          'email': user.email,
          'phoneNumber': user.phoneNumber ?? fallbackPhoneNumber,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await FcmTokenRepository(
      firestore: _firestore,
      auth: _auth,
      messaging: _messaging,
    ).syncTokenForCurrentUser();

    final DocumentSnapshot<Map<String, dynamic>> fresh = await userRef.get();
    return CustomerProfile.merge(user, fresh.data());
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await FcmTokenRepository(
        firestore: _firestore,
        auth: _auth,
        messaging: _messaging,
      ).clearTokenForCurrentUser();
      await _messaging.deleteToken();
    } catch (_) {}

    try {
      await _auth.signOut();
      _sessionId = null;
      state = const PhoneAuthState(
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Logout failed. Please try again.',
      );
    }
  }

  /// Deletes Auth user + customer profile data (Play Store account deletion).
  Future<void> deleteAccount() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final User? user = _auth.currentUser;
    if (user == null) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'You must be signed in to delete your account.',
      );
      return;
    }

    final String uid = user.uid;

    try {
      await FcmTokenRepository(
        firestore: _firestore,
        auth: _auth,
        messaging: _messaging,
      ).clearTokenForCurrentUser();
    } catch (_) {}

    try {
      await CustomerProfileRepository(
        auth: _auth,
        firestore: _firestore,
      ).wipeAccountOwnedData(uid);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage:
            'Could not remove your profile data. Please try again or contact support.',
      );
      return;
    }

    try {
      await user.delete();
      _sessionId = null;
      state = const PhoneAuthState(isLoading: false);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        state = state.copyWith(
          isLoading: false,
          errorMessage:
              'For security, sign out, sign in again with OTP, then delete your account.',
        );
        return;
      }
      debugPrint('Account delete failed: code=${e.code} message=${e.message}');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Could not delete your account. Please try again.',
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Could not delete your account. Please try again.',
      );
    }
  }
}
