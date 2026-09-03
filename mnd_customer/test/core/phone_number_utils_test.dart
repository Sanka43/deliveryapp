import 'package:flutter_test/flutter_test.dart';
import 'package:mnd_delivery_app/core/utils/phone_number_utils.dart';

void main() {
  group('PhoneNumberUtils.toE164', () {
    test('strips leading trunk 0 for Sri Lanka', () {
      expect(
        PhoneNumberUtils.toE164(
          dialCode: '+94',
          nationalNumber: '0771234567',
        ),
        '+94771234567',
      );
    });

    test('keeps number without leading 0', () {
      expect(
        PhoneNumberUtils.toE164(
          dialCode: '+94',
          nationalNumber: '771234567',
        ),
        '+94771234567',
      );
    });
  });

  group('PhoneNumberUtils.validateNationalNumber', () {
    test('requires 9 digits for +94 after stripping 0', () {
      expect(
        PhoneNumberUtils.validateNationalNumber(
          dialCode: '+94',
          nationalNumber: '0771234567',
        ),
        isNull,
      );
      expect(
        PhoneNumberUtils.validateNationalNumber(
          dialCode: '+94',
          nationalNumber: '77123456',
        ),
        isNotNull,
      );
    });

    test('rejects empty', () {
      expect(
        PhoneNumberUtils.validateNationalNumber(
          dialCode: '+94',
          nationalNumber: '',
        ),
        'Phone number is required',
      );
    });
  });
}
