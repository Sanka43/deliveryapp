import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_rider/features/profile/data/rider_profile_edit_validator.dart';
import 'package:mnd_rider/features/profile/data/rider_profile_repository.dart';
import 'package:mnd_rider/features/profile/domain/rider_profile_edit_form.dart';

class RiderProfileEditState {
  const RiderProfileEditState({
    required this.form,
    this.isLoading = false,
    this.errorMessage,
    this.fieldErrors = const <String, String>{},
  });

  final RiderProfileEditForm form;
  final bool isLoading;
  final String? errorMessage;
  final Map<String, String> fieldErrors;

  RiderProfileEditState copyWith({
    RiderProfileEditForm? form,
    bool? isLoading,
    String? errorMessage,
    Map<String, String>? fieldErrors,
    bool clearError = false,
  }) {
    return RiderProfileEditState(
      form: form ?? this.form,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      fieldErrors: fieldErrors ?? this.fieldErrors,
    );
  }
}

final StateNotifierProviderFamily<RiderProfileEditController,
    RiderProfileEditState, RiderProfileEditForm> riderProfileEditProvider =
    StateNotifierProvider.family<RiderProfileEditController, RiderProfileEditState,
        RiderProfileEditForm>(
  RiderProfileEditController.new,
);

class RiderProfileEditController extends StateNotifier<RiderProfileEditState> {
  RiderProfileEditController(this._ref, RiderProfileEditForm initial)
      : super(RiderProfileEditState(form: initial));

  final Ref _ref;

  void updateForm(RiderProfileEditForm form) {
    state = state.copyWith(form: form, fieldErrors: <String, String>{});
  }

  Future<bool> submit() async {
    final RiderProfileEditValidationResult validation =
        const RiderProfileEditValidator().validate(state.form);
    if (!validation.isValid) {
      state = state.copyWith(fieldErrors: validation.fieldErrors);
      return false;
    }

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      fieldErrors: <String, String>{},
    );

    final String? err = await _ref
        .read(riderProfileRepositoryProvider)
        .updateProfile(form: state.form);

    if (err != null) {
      state = state.copyWith(isLoading: false, errorMessage: err);
      return false;
    }

    state = state.copyWith(isLoading: false, clearError: true);
    return true;
  }
}
