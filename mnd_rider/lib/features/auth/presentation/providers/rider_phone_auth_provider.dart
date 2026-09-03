import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_rider/features/auth/data/rider_auth_repository.dart';
import 'package:mnd_rider/features/auth/data/rider_registration_validator.dart';

class RiderPhoneAuthState {
  const RiderPhoneAuthState({
    this.isLoading = false,
    this.errorMessage,
    this.verificationId,
    this.e164Phone,
    this.intent = '',
  });

  final bool isLoading;
  final String? errorMessage;

  /// SMSlenz OTP session id from [sendOtp].
  final String? verificationId;
  final String? e164Phone;

  /// `register` when OTP should finish registration after verify.
  final String intent;

  bool get hasPendingOtpSession =>
      verificationId != null &&
      verificationId!.isNotEmpty &&
      e164Phone != null &&
      e164Phone!.isNotEmpty;

  RiderPhoneAuthState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? verificationId,
    String? e164Phone,
    String? intent,
    bool clearError = false,
    bool clearSession = false,
  }) {
    return RiderPhoneAuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      verificationId:
          clearSession ? null : (verificationId ?? this.verificationId),
      e164Phone: clearSession ? null : (e164Phone ?? this.e164Phone),
      intent: clearSession ? '' : (intent ?? this.intent),
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
  bool _sendInFlight = false;

  static const String dialCode = '+94';

  Future<String?> sendOtp(
    String localPhoneDigits, {
    String intent = '',
    bool force = false,
  }) async {
    if (_sendInFlight || state.isLoading) {
      return null;
    }
    // `force` is the Resend path — keep the in-memory session until a new
    // sessionId is returned (do not clear it here).
    if (force) {
      state = state.copyWith(clearError: true);
    }

    final String? validation =
        const RiderRegistrationValidator().validatePhoneLogin(localPhoneDigits);
    if (validation != null) {
      state = state.copyWith(errorMessage: validation);
      return null;
    }

    _sendInFlight = true;
    // Keep the existing session until a new sessionId arrives so Resend
    // cannot bounce the OTP screen back to login.
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final String e164 = normalizeSriLankaPhone(dialCode, localPhoneDigits);
      final String purpose = intent.trim().toLowerCase() == 'register'
          ? 'rider_register'
          : 'rider_login';
      final String verificationId =
          await _ref.read(riderAuthRepositoryProvider).sendPhoneOtp(
                e164,
                purpose: purpose,
              );

      state = state.copyWith(
        isLoading: false,
        clearError: true,
        verificationId: verificationId,
        e164Phone: e164,
        intent: intent,
      );
      return verificationId;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: RiderAuthRepository.mapAuthError(e),
      );
      return null;
    } finally {
      _sendInFlight = false;
    }
  }

  Future<bool> verifyOtp({
    required String verificationId,
    required String e164Phone,
    required String otp,
  }) async {
    if (state.isLoading) {
      return false;
    }
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

  void clearError() => state = state.copyWith(clearError: true);

  void clearSession() => state = state.copyWith(clearSession: true);
}
