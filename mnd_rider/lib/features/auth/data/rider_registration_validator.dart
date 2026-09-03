import 'dart:typed_data';

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

  /// Sri Lanka mobile: 9 digits starting with 7 (771234567) or leading 0 (0771234567).
  static final RegExp _phoneLocalPattern = RegExp(r'^(0)?7[0-9]{8}$');

  static const List<Set<String>> stepFieldKeys = <Set<String>>[
    <String>{'fullName', 'phone', 'nicNumber', 'city'},
    <String>{'profilePhoto', 'licensePhoto'},
    <String>{
      'vehicleType',
      'vehicleNumber',
      'vehiclePhoto_front',
      'vehiclePhoto_back',
      'vehiclePhoto_left',
      'vehiclePhoto_right',
      'licenseExpiresAt',
      'insurancePhoto',
      'insuranceExpiresAt',
      'revenueLicensePhoto',
      'revenueLicenseExpiresAt',
    },
  ];

  RiderRegistrationValidationResult validate(RiderRegistrationForm form) {
    return RiderRegistrationValidationResult(fieldErrors: _collectErrors(form));
  }

  /// Validates only fields for the given wizard step (0–2).
  RiderRegistrationValidationResult validateStep(
    RiderRegistrationForm form,
    int step,
  ) {
    final Set<String> keys =
        step >= 0 && step < stepFieldKeys.length ? stepFieldKeys[step] : <String>{};
    final Map<String, String> all = _collectErrors(form);
    final Map<String, String> filtered = <String, String>{
      for (final MapEntry<String, String> e in all.entries)
        if (keys.contains(e.key)) e.key: e.value,
    };
    return RiderRegistrationValidationResult(fieldErrors: filtered);
  }

  Map<String, String> _collectErrors(RiderRegistrationForm form) {
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

    for (final RiderVehiclePhotoSide side in RiderVehiclePhotoSide.values) {
      final Uint8List? bytes = form.vehiclePhotoBytesFor(side);
      if (bytes == null || bytes.isEmpty) {
        errors[side.fieldErrorKey] = 'Add a ${side.label.toLowerCase()} photo.';
      }
    }

    if (form.licenseExpiresAt == null) {
      errors['licenseExpiresAt'] = 'Select license expiry date.';
    } else if (!_isFutureOrToday(form.licenseExpiresAt!)) {
      errors['licenseExpiresAt'] = 'License must not be expired.';
    }

    if (form.insurancePhotoBytes == null || form.insurancePhotoBytes!.isEmpty) {
      errors['insurancePhoto'] = 'Add a photo of your insurance.';
    }

    if (form.insuranceExpiresAt == null) {
      errors['insuranceExpiresAt'] = 'Select insurance expiry date.';
    } else if (!_isFutureOrToday(form.insuranceExpiresAt!)) {
      errors['insuranceExpiresAt'] = 'Insurance must not be expired.';
    }

    if (form.revenueLicensePhotoBytes == null ||
        form.revenueLicensePhotoBytes!.isEmpty) {
      errors['revenueLicensePhoto'] = 'Add a photo of your revenue license.';
    }

    if (form.revenueLicenseExpiresAt == null) {
      errors['revenueLicenseExpiresAt'] = 'Select revenue license expiry date.';
    } else if (!_isFutureOrToday(form.revenueLicenseExpiresAt!)) {
      errors['revenueLicenseExpiresAt'] = 'Revenue license must not be expired.';
    }

    return errors;
  }

  bool _isFutureOrToday(DateTime date) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime day = DateTime(date.year, date.month, date.day);
    return !day.isBefore(today);
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
