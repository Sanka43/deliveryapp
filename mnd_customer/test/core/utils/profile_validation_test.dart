import 'package:flutter_test/flutter_test.dart';
import 'package:mnd_delivery_app/core/utils/profile_validation.dart';
import 'package:mnd_delivery_app/features/customer/domain/entities/customer_profile.dart';

CustomerProfile _profile(String name) =>
    CustomerProfile(id: 'u1', name: name, phone: '+94771234567');

void main() {
  group('validateProfileName', () {
    test('rejects empty and whitespace', () {
      expect(validateProfileName(null), ProfileNameError.empty);
      expect(validateProfileName('   '), ProfileNameError.empty);
    });

    test('rejects a single character', () {
      expect(validateProfileName(' A '), ProfileNameError.tooShort);
    });

    test('rejects names over the max length', () {
      expect(validateProfileName('a' * 81), ProfileNameError.tooLong);
      expect(validateProfileName('a' * 80), isNull);
    });

    test('rejects the Customer placeholder in any case', () {
      expect(validateProfileName('Customer'), ProfileNameError.placeholder);
      expect(validateProfileName(' cUsToMeR '), ProfileNameError.placeholder);
    });

    test('accepts real names including Sinhala and Tamil', () {
      expect(validateProfileName('Kamal Perera'), isNull);
      expect(validateProfileName('කමල්'), isNull);
      expect(validateProfileName('கமல்'), isNull);
    });
  });

  group('isValidOptionalEmail', () {
    test('empty is valid because email is optional', () {
      expect(isValidOptionalEmail(null), isTrue);
      expect(isValidOptionalEmail('  '), isTrue);
    });

    test('accepts a normal address', () {
      expect(isValidOptionalEmail('kamal@example.lk'), isTrue);
      expect(isValidOptionalEmail(' kamal+mnd@mail.example.com '), isTrue);
    });

    test('rejects missing @ or TLD', () {
      expect(isValidOptionalEmail('kamal'), isFalse);
      expect(isValidOptionalEmail('kamal@example'), isFalse);
      expect(isValidOptionalEmail('kamal@'), isFalse);
    });
  });

  group('CustomerProfile.hasRealName', () {
    test('false for the merge fallback and too-short names', () {
      expect(_profile('Customer').hasRealName, isFalse);
      expect(_profile('A').hasRealName, isFalse);
      expect(_profile('').hasRealName, isFalse);
    });

    test('true for real names', () {
      expect(_profile('Kamal Perera').hasRealName, isTrue);
    });

    test('an over-long saved name still counts, so users are not trapped', () {
      expect(_profile('a' * 120).hasRealName, isTrue);
    });
  });
}
