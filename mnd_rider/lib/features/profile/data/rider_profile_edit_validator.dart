import 'package:mnd_rider/features/auth/data/rider_registration_validator.dart';
import 'package:mnd_rider/features/profile/domain/rider_profile_edit_form.dart';

class RiderProfileEditValidationResult {
  const RiderProfileEditValidationResult({
    this.fieldErrors = const <String, String>{},
  });

  final Map<String, String> fieldErrors;

  bool get isValid => fieldErrors.isEmpty;

  String? operator [](String key) => fieldErrors[key];
}

class RiderProfileEditValidator {
  const RiderProfileEditValidator();

  static final RegExp _nicPattern = RegExp(r'^(\d{9}[vVxX]|\d{12})$');

  RiderProfileEditValidationResult validate(RiderProfileEditForm form) {
    final Map<String, String> errors = <String, String>{};

    if (form.fullName.trim().length < 2) {
      errors['fullName'] = 'Enter your full name (at least 2 characters).';
    }

    final String? phoneErr =
        const RiderRegistrationValidator().validatePhoneLogin(form.phoneLocal);
    if (phoneErr != null) {
      errors['phone'] = phoneErr;
    }

    if (!_nicPattern.hasMatch(form.nicNumber.trim())) {
      errors['nicNumber'] = 'Enter a valid NIC (9 digits + V or 12 digits).';
    }

    if (form.city.trim().length < 2) {
      errors['city'] = 'Enter your city.';
    }

    if (form.vehicleNumber.trim().length < 3) {
      errors['vehicleNumber'] = 'Enter a valid vehicle number.';
    }

    return RiderProfileEditValidationResult(fieldErrors: errors);
  }
}
