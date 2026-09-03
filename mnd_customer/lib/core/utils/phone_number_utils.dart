/// Helpers for E.164 phone numbers used by Firebase Phone Auth.
class PhoneNumberUtils {
  PhoneNumberUtils._();

  /// Builds an E.164 number from [dialCode] (e.g. `+94`) and national digits.
  ///
  /// Strips a leading `0` from the national number so `077…` + `+94` becomes
  /// `+9477…` instead of the invalid `+94077…`.
  static String toE164({
    required String dialCode,
    required String nationalNumber,
  }) {
    String digits = nationalNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    final String code = dialCode.trim().startsWith('+')
        ? dialCode.trim()
        : '+${dialCode.trim()}';
    return '$code$digits';
  }

  /// National digits only, with a leading trunk `0` removed when present.
  static String nationalDigits(String value) {
    String digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return digits;
  }

  /// Lightweight length check before calling Firebase.
  static String? validateNationalNumber({
    required String dialCode,
    required String? nationalNumber,
  }) {
    final String raw = nationalNumber?.trim() ?? '';
    if (raw.isEmpty) {
      return 'Phone number is required';
    }
    final String digits = nationalDigits(raw);
    if (digits.isEmpty) {
      return 'Enter a valid phone number';
    }

    switch (dialCode) {
      case '+94':
        if (digits.length != 9) {
          return 'Enter a valid Sri Lankan mobile number';
        }
        break;
      case '+91':
        if (digits.length != 10) {
          return 'Enter a valid Indian mobile number';
        }
        break;
      case '+1':
        if (digits.length != 10) {
          return 'Enter a valid phone number';
        }
        break;
      case '+44':
        if (digits.length < 9 || digits.length > 10) {
          return 'Enter a valid UK phone number';
        }
        break;
      default:
        if (digits.length < 8 || digits.length > 12) {
          return 'Enter a valid phone number';
        }
    }
    return null;
  }
}
