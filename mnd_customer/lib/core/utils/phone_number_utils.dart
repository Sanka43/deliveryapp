import 'package:mnd_delivery_app/l10n/generated/app_localizations.dart';

/// Machine-readable phone validation failure — kept locale-free so
/// [PhoneNumberUtils] doesn't need a [BuildContext]. Map to user-facing copy
/// with [PhoneValidationErrorL10n.message] at the call site.
enum PhoneValidationError {
  required,
  invalid,
  invalidSriLankan,
  invalidIndian,
  invalidUk,
}

extension PhoneValidationErrorL10n on PhoneValidationError {
  String message(AppLocalizations l10n) {
    switch (this) {
      case PhoneValidationError.required:
        return l10n.phoneValidationRequired;
      case PhoneValidationError.invalid:
        return l10n.phoneValidationInvalid;
      case PhoneValidationError.invalidSriLankan:
        return l10n.phoneValidationInvalidSriLankan;
      case PhoneValidationError.invalidIndian:
        return l10n.phoneValidationInvalidIndian;
      case PhoneValidationError.invalidUk:
        return l10n.phoneValidationInvalidUk;
    }
  }
}

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
  static PhoneValidationError? validateNationalNumber({
    required String dialCode,
    required String? nationalNumber,
  }) {
    final String raw = nationalNumber?.trim() ?? '';
    if (raw.isEmpty) {
      return PhoneValidationError.required;
    }
    final String digits = nationalDigits(raw);
    if (digits.isEmpty) {
      return PhoneValidationError.invalid;
    }

    switch (dialCode) {
      case '+94':
        if (digits.length != 9) {
          return PhoneValidationError.invalidSriLankan;
        }
        break;
      case '+91':
        if (digits.length != 10) {
          return PhoneValidationError.invalidIndian;
        }
        break;
      case '+1':
        if (digits.length != 10) {
          return PhoneValidationError.invalid;
        }
        break;
      case '+44':
        if (digits.length < 9 || digits.length > 10) {
          return PhoneValidationError.invalidUk;
        }
        break;
      default:
        if (digits.length < 8 || digits.length > 12) {
          return PhoneValidationError.invalid;
        }
    }
    return null;
  }
}
