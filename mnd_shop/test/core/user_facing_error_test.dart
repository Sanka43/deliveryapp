import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnd_shop/core/utils/user_facing_error.dart';

void main() {
  group('userFacingError', () {
    test('never returns raw firestore dumps', () {
      final String msg = userFacingError(
        Exception('[cloud_firestore/permission-denied] Missing rules'),
      );
      expect(msg.toLowerCase(), isNot(contains('cloud_firestore')));
      expect(msg.toLowerCase(), isNot(contains('permission-denied')));
      expect(msg, isNot(contains('Exception')));
    });

    test('maps auth network failures', () {
      final String msg = userFacingError(
        FirebaseAuthException(code: 'network-request-failed'),
      );
      expect(msg.toLowerCase(), contains('network'));
    });

    test('keeps safe callable messages', () {
      final String msg = userFacingError(
        FirebaseFunctionsException(
          code: 'failed-precondition',
          message: 'This shop is closed right now.',
        ),
      );
      expect(msg, 'This shop is closed right now.');
    });

    test('strips Exception: prefix for intentional messages', () {
      final String msg = userFacingError(
        Exception('Location request timed out. Try again.'),
      );
      expect(msg, 'Location request timed out. Try again.');
    });

    test('blocks ops-facing vendor doc copy', () {
      final String msg = userFacingError(
        Exception('Vendor doc missing in Firestore. Create vendors/abc (admin).'),
        fallback: 'Could not update your shop. Please try again.',
      );
      expect(msg.toLowerCase(), isNot(contains('firestore')));
      expect(msg.toLowerCase(), isNot(contains('admin')));
      expect(msg, 'Could not update your shop. Please try again.');
    });
  });
}
