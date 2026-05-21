import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_rider/features/auth/data/rider_auth_repository.dart';
import 'package:mnd_rider/features/auth/data/rider_registration_validator.dart';

class RiderPhoneAuthState {
  const RiderPhoneAuthState({
    this.isLoading = false,
    this.errorMessage,
  });

  final bool isLoading;
  final String? errorMessage;

  RiderPhoneAuthState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return RiderPhoneAuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final StateNotifierProvider<RiderPhoneAuthController, RiderPhoneAuthState>
    riderPhoneAuthProvider =
    StateNotifierProvider<RiderPhoneAuthController, RiderPhoneAuthState>(
  (Ref ref) => RiderPhoneAuthController(ref),
);

class RiderPhoneAuthController extends StateNotifier<RiderPhoneAuthState> {
  RiderPhoneAuthController(this._ref) : super(const RiderPhoneAuthState());

  final Ref _ref;

  static const String dialCode = '+94';

  Future<String?> sendOtp(String localPhoneDigits) async {
    final String? validation =
        const RiderRegistrationValidator().validatePhoneLogin(localPhoneDigits);
    if (validation != null) {
      state = state.copyWith(errorMessage: validation);
      return null;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final String e164 = normalizeSriLankaPhone(dialCode, localPhoneDigits);
      final String verificationId =
          await _ref.read(riderAuthRepositoryProvider).sendPhoneOtp(e164);

      if (kDebugMode && verificationId.isEmpty) {
        state = state.copyWith(isLoading: false, clearError: true);
        return kTemporaryOtpVerificationId;
      }

      state = state.copyWith(isLoading: false, clearError: true);
      return verificationId;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: RiderAuthRepository.mapAuthError(e),
      );
      return null;
    }
  }

  Future<bool> verifyOtp({
    required String verificationId,
    required String e164Phone,
    required String otp,
  }) async {
    final String? validation = const RiderRegistrationValidator().validateOtp(otp);
    if (validation != null) {
      state = state.copyWith(errorMessage: validation);
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _ref.read(riderAuthRepositoryProvider).verifyPhoneOtp(
            verificationId: verificationId,
            smsCode: otp,
            e164Phone: e164Phone,
          );
      state = state.copyWith(isLoading: false, clearError: true);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: RiderAuthRepository.mapAuthError(e),
      );
      return false;
    }
  }

  Future<bool> signInWithPassword({
    required String localPhoneDigits,
    required String password,
  }) async {
    final String? validation =
        const RiderRegistrationValidator().validatePhoneLogin(localPhoneDigits);
    if (validation != null) {
      state = state.copyWith(errorMessage: validation);
      return false;
    }
    if (password.trim().length < 8) {
      state = state.copyWith(errorMessage: 'Enter your password (8+ characters).');
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final String e164 = normalizeSriLankaPhone(dialCode, localPhoneDigits);
      await _ref.read(riderAuthRepositoryProvider).signInWithPhonePassword(
            e164Phone: e164,
            password: password.trim(),
          );
      state = state.copyWith(isLoading: false, clearError: true);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: RiderAuthRepository.mapAuthError(e),
      );
      return false;
    }
  }

  void clearError() => state = state.copyWith(clearError: true);
}
