import 'package:flutter_test/flutter_test.dart';
import 'package:mnd_shop/features/auth/domain/vendor_deletion_status.dart';

void main() {
  group('VendorDeletionStatus', () {
    test('blocks only pending deletion while processing', () {
      expect(
        VendorDeletionStatus.blocksAppAccess(<String, dynamic>{
          'accountDeletionStatus': 'pending',
        }),
        isTrue,
      );
      expect(
        VendorDeletionStatus.blocksAppAccess(<String, dynamic>{
          'accountDeletionStatus': 'auth_deleted',
        }),
        isFalse,
      );
      expect(VendorDeletionStatus.blocksAppAccess(<String, dynamic>{}), isFalse);
    });

    test('flags closed shops that need re-registration', () {
      expect(
        VendorDeletionStatus.needsReRegistration(<String, dynamic>{
          'accountDeletionStatus': 'auth_deleted',
        }),
        isTrue,
      );
      expect(
        VendorDeletionStatus.needsReRegistration(<String, dynamic>{
          'accountDeletionStatus': 'pending',
        }),
        isFalse,
      );
      expect(VendorDeletionStatus.needsReRegistration(<String, dynamic>{}), isFalse);
    });

    test('allows deletion request only when status is empty', () {
      expect(VendorDeletionStatus.canRequestDeletion(<String, dynamic>{}), isTrue);
      expect(
        VendorDeletionStatus.canRequestDeletion(<String, dynamic>{
          'accountDeletionStatus': 'pending',
        }),
        isFalse,
      );
    });
  });
}
