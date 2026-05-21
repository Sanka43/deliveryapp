import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_rider/app/providers/rider_auth_state_provider.dart';
import 'package:mnd_rider/features/auth/data/rider_auth_repository.dart';
import 'package:mnd_rider/features/auth/data/rider_registration_validator.dart';
import 'package:mnd_rider/features/auth/domain/rider_profile_document.dart';
import 'package:mnd_rider/features/auth/domain/rider_registration_form.dart';

final StreamProvider<RiderProfileDocument?> riderAuthProfileProvider =
    StreamProvider<RiderProfileDocument?>((Ref ref) {
  final String? uid = ref.watch(riderAuthStateProvider).valueOrNull?.uid;
  if (uid == null) {
    return Stream<RiderProfileDocument?>.value(null);
  }
  return ref.watch(riderAuthRepositoryProvider).watchRiderProfile(uid);
});

final Provider<AsyncValue<bool>> riderHasCompleteProfileProvider =
    Provider<AsyncValue<bool>>((Ref ref) {
  return ref.watch(riderAuthProfileProvider).whenData(
        (RiderProfileDocument? doc) => doc?.isRegistrationComplete ?? false,
      );
});

class RiderRegistrationSubmitState {
  const RiderRegistrationSubmitState({
    this.isLoading = false,
    this.errorMessage,
    this.fieldErrors = const <String, String>{},
  });

  final bool isLoading;
  final String? errorMessage;
  final Map<String, String> fieldErrors;

  RiderRegistrationSubmitState copyWith({
    bool? isLoading,
    String? errorMessage,
    Map<String, String>? fieldErrors,
    bool clearError = false,
  }) {
    return RiderRegistrationSubmitState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      fieldErrors: fieldErrors ?? this.fieldErrors,
    );
  }
}

final StateNotifierProvider<RiderRegistrationFormNotifier, RiderRegistrationForm>
    riderRegistrationFormProvider =
    StateNotifierProvider<RiderRegistrationFormNotifier, RiderRegistrationForm>(
  (Ref ref) => RiderRegistrationFormNotifier(),
);

class RiderRegistrationFormNotifier extends StateNotifier<RiderRegistrationForm> {
  RiderRegistrationFormNotifier() : super(const RiderRegistrationForm());

  void update(RiderRegistrationForm form) => state = form;
}

final StateNotifierProvider<RiderRegistrationController, RiderRegistrationSubmitState>
    riderRegistrationSubmitProvider =
    StateNotifierProvider<RiderRegistrationController, RiderRegistrationSubmitState>(
  (Ref ref) => RiderRegistrationController(ref),
);

class RiderRegistrationController extends StateNotifier<RiderRegistrationSubmitState> {
  RiderRegistrationController(this._ref) : super(const RiderRegistrationSubmitState());

  final Ref _ref;
  final RiderRegistrationValidator _validator = const RiderRegistrationValidator();

  String _mapSubmitError(Object e) {
    return RiderAuthRepository.mapAuthError(e);
  }

  Future<bool> submit() async {
    final RiderRegistrationForm form = _ref.read(riderRegistrationFormProvider);
    final RiderRegistrationValidationResult result = _validator.validate(form);
    if (!result.isValid) {
      state = state.copyWith(fieldErrors: result.fieldErrors, clearError: true);
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true, fieldErrors: <String, String>{});
    try {
      await _ref.read(riderAuthRepositoryProvider).registerRider(form);
      state = state.copyWith(isLoading: false, clearError: true);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _mapSubmitError(e),
      );
      return false;
    }
  }
}
