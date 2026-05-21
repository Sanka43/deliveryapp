import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/app/providers/firebase_providers.dart';
import 'package:mnd_delivery_app/core/constants/firebase_collections.dart';
import 'package:mnd_delivery_app/core/services/fcm_token_repository.dart';
import 'package:mnd_delivery_app/firebase_options.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Debug-only OTP screen: pass this as the SMS [verificationId] (see [LoginPage]).
const String kTemporaryOtpVerificationId = '__MND_TEMP_OTP__';

class PhoneAuthState {
  const PhoneAuthState({
    this.isLoading = false,
    this.errorMessage,
  });

  final bool isLoading;
  final String? errorMessage;

  PhoneAuthState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PhoneAuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final StateNotifierProvider<PhoneAuthController, PhoneAuthState> phoneAuthControllerProvider =
    StateNotifierProvider<PhoneAuthController, PhoneAuthState>(
  (Ref ref) {
    return PhoneAuthController(
      ref.read(firebaseAuthProvider),
      ref.read(firestoreProvider),
      ref.read(firebaseMessagingProvider),
      ref.read(googleSignInProvider),
    );
  },
);

class PhoneAuthController extends StateNotifier<PhoneAuthState> {
  PhoneAuthController(
    this._auth,
    this._firestore,
    this._messaging,
    this._googleSignIn,
  )
      : super(const PhoneAuthState());

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseMessaging _messaging;
  final GoogleSignIn _googleSignIn;

  static const String _temporaryOtpCode = '123456';
  static const String _temporaryDevPassword = 'MndTempOtp123456!';

  static String _debugEmailForPhone(String phoneNumber) {
    final String digits = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final String safe = digits.isEmpty ? '0' : digits;
    final String projectId = DefaultFirebaseOptions.currentPlatform.projectId;
    return 'mnd-temp-debug.$safe@$projectId.firebaseapp.com';
  }

  /// Debug builds only: signs in with Email/Password (one Firebase user per phone)
  /// when [smsCode] is [_temporaryOtpCode]. Writes/merges `customers/{uid}` like phone OTP.
  ///
  /// Requires **Email/Password** enabled in Firebase Authentication for this project.
  Future<bool> signInWithTemporaryOtp({
    required String phoneNumber,
    required String smsCode,
  }) async {
    if (!kDebugMode) {
      state = state.copyWith(
        isLoading: false,
        errorMessage:
            'Invalid or expired code. Request a new OTP and try again.',
      );
      return false;
    }
    if (smsCode.trim() != _temporaryOtpCode) {
      state = state.copyWith(
        isLoading: false,
        errorMessage:
            'Invalid or expired code. Request a new OTP and try again.',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    final String email = _debugEmailForPhone(phoneNumber);

    try {
      UserCredential credential;
      try {
        credential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: _temporaryDevPassword,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' ||
            e.code == 'wrong-password' ||
            e.code == 'invalid-credential') {
          try {
            credential = await _auth.createUserWithEmailAndPassword(
              email: email,
              password: _temporaryDevPassword,
            );
          } on FirebaseAuthException catch (createError) {
            if (createError.code == 'email-already-in-use') {
              credential = await _auth.signInWithEmailAndPassword(
                email: email,
                password: _temporaryDevPassword,
              );
            } else {
              rethrow;
            }
          }
        } else {
          rethrow;
        }
      }

      await _ensureUserProfile(
        credential.user,
        fallbackPhoneNumber: phoneNumber,
      );
      state = state.copyWith(
        isLoading: false,
        clearError: true,
      );
      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _temporaryAuthErrorMessage(e),
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage:
            'Temporary login failed. Enable Email/Password in Firebase Console and try again.',
      );
      return false;
    }
  }

  static String _temporaryAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'operation-not-allowed':
        return 'Email/Password sign-in is not enabled in Firebase Console.';
      case 'invalid-email':
        return 'Could not build a dev login email for this phone number.';
      default:
        return e.message ?? 'Temporary login failed.';
    }
  }

  static String _otpSendErrorMessage(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-phone-number':
          return 'This phone number format is not valid.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        case 'quota-exceeded':
          return 'SMS quota exceeded. Please try again later.';
        case 'missing-client-identifier':
        case 'app-not-authorized':
          final String base =
              'This app is not authorized to send SMS. In Firebase Console add SHA-1 and SHA-256 for this build, re-download google-services.json, and ensure this package+SHA is not registered in another Firebase project.';
          if (kDebugMode) {
            return '$base [${e.code}]';
          }
          return base;
        case 'operation-not-allowed':
          return 'Phone sign-in is not enabled in Firebase Console.';
        default:
          return e.message ?? 'Could not send verification code.';
      }
    }
    return 'Could not send verification code. Please try again.';
  }

  Future<String?> sendOtp(String phoneNumber) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final Completer<String?> completer = Completer<String?>();

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            final UserCredential userCredential =
                await _auth.signInWithCredential(credential);
            await _ensureUserProfile(
              userCredential.user,
              fallbackPhoneNumber: userCredential.user?.phoneNumber,
            );
            if (!completer.isCompleted) {
              completer.complete(null);
            }
          } on FirebaseAuthException catch (e) {
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

      final String? verificationId = await completer.future;
      state = state.copyWith(
        isLoading: false,
        clearError: true,
      );
      return verificationId;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _otpSendErrorMessage(e),
      );
      return null;
    }
  }

  Future<bool> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      await _ensureUserProfile(
        userCredential.user,
        fallbackPhoneNumber: userCredential.user?.phoneNumber,
      );
      state = state.copyWith(
        isLoading: false,
        clearError: true,
      );
      return true;
    } on FirebaseAuthException catch (e) {
      final String message = e.code == 'invalid-verification-code'
          ? 'Invalid or expired code. Request a new OTP and try again.'
          : (e.message ?? 'Invalid OTP code');
      state = state.copyWith(
        isLoading: false,
        errorMessage: message,
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'OTP verification failed. Please try again.',
      );
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  Future<bool> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        state = state.copyWith(isLoading: false, clearError: true);
        return false;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      await _ensureUserProfile(
        userCredential.user,
      );
      state = state.copyWith(
        isLoading: false,
        clearError: true,
      );
      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message ?? 'Google Sign-In failed',
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Google Sign-In failed. Please try again.',
      );
      return false;
    }
  }

  Future<void> _ensureUserProfile(
    User? user, {
    String? fallbackPhoneNumber,
  }) async {
    if (user == null) {
      return;
    }

    final DocumentReference<Map<String, dynamic>> userRef = _firestore
        .collection(FirebaseCollections.customers)
        .doc(user.uid);
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
      return;
    }

    await userRef.set(
      <String, dynamic>{
        'displayName': user.displayName,
        'email': user.email,
        'phoneNumber': user.phoneNumber ?? fallbackPhoneNumber,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await FcmTokenRepository(
      firestore: _firestore,
      auth: _auth,
      messaging: _messaging,
    ).syncTokenForCurrentUser();
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await FcmTokenRepository(
        firestore: _firestore,
        auth: _auth,
        messaging: _messaging,
      ).clearTokenForCurrentUser();
      // Invalidate push token on this device as part of logout cleanup.
      await _messaging.deleteToken();
    } catch (_) {}

    try {
      await _googleSignIn.disconnect();
    } catch (_) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
    }

    try {
      await _auth.signOut();
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
}
