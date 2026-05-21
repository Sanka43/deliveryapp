import 'package:mnd_rider/features/auth/domain/rider_registration_form.dart';

class RiderRegistrationValidationResult {
  const RiderRegistrationValidationResult({
    this.fieldErrors = const <String, String>{},
  });

  final Map<String, String> fieldErrors;

  bool get isValid => fieldErrors.isEmpty;

  String? operator [](String key) => fieldErrors[key];
}

class RiderRegistrationValidator {
  const RiderRegistrationValidator();

  static final RegExp _nicPattern = RegExp(
    r'^(\d{9}[vVxX]|\d{12})$',
  );

  /// 9 digits (771234567) or 10 with leading 0 (0771234567).
  static final RegExp _phoneLocalPattern = RegExp(r'^(0)?[0-9]{9}$');

  RiderRegistrationValidationResult validate(RiderRegistrationForm form) {
    final Map<String, String> errors = <String, String>{};

    if (form.fullName.trim().length < 2) {
      errors['fullName'] = 'Enter your full name (at least 2 characters).';
    }

    if (!_phoneLocalPattern.hasMatch(form.phone.trim())) {
      errors['phone'] =
          'Enter a valid mobile number (e.g. 771234567 or 0771234567).';
    }

    if (!_nicPattern.hasMatch(form.nicNumber.trim())) {
      errors['nicNumber'] = 'Enter a valid NIC (9 digits + V or 12 digits).';
    }

    if (form.password.length < 8) {
      errors['password'] = 'Password must be at least 8 characters.';
    }

    if (form.password != form.confirmPassword) {
      errors['confirmPassword'] = 'Passwords do not match.';
    }

    if (form.vehicleType == null) {
      errors['vehicleType'] = 'Select your vehicle type.';
    }

    if (form.vehicleNumber.trim().length < 3) {
      errors['vehicleNumber'] = 'Enter a valid vehicle number.';
    }

    if (form.city.trim().length < 2) {
      errors['city'] = 'Enter your city.';
    }

    if (form.profilePhotoBytes == null || form.profilePhotoBytes!.isEmpty) {
      errors['profilePhoto'] = 'Add a profile photo.';
    }

    if (form.licensePhotoBytes == null || form.licensePhotoBytes!.isEmpty) {
      errors['licensePhoto'] = 'Add a photo of your driving license.';
    }

    return RiderRegistrationValidationResult(fieldErrors: errors);
  }

  String? validatePhoneLogin(String localDigits) {
    if (!_phoneLocalPattern.hasMatch(localDigits.trim())) {
      return 'Enter a valid mobile number (e.g. 771234567).';
    }
    return null;
  }

  String? validateOtp(String code) {
    final String trimmed = code.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(trimmed)) {
      return 'Enter the 6-digit code.';
    }
    return null;
  }
}

/// Normalizes local input to 9 digits (strips leading 0 and +94 prefixes).
String normalizeLocalSriLankaDigits(String raw) {
  String digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.startsWith('94') && digits.length >= 11) {
    digits = digits.substring(digits.length - 9);
  }
  if (digits.length == 10 && digits.startsWith('0')) {
    digits = digits.substring(1);
  }
  return digits;
}

String normalizeSriLankaPhone(String dialCode, String localDigits) {
  final String local = normalizeLocalSriLankaDigits(localDigits);
  final String code = dialCode.startsWith('+') ? dialCode : '+$dialCode';
  return '$code$local';
}

String authEmailForPhone(String e164Phone) {
  final String digits = e164Phone.replaceAll(RegExp(r'[^0-9]'), '');
  return 'rider.$digits@riders.mnd.app';
}
