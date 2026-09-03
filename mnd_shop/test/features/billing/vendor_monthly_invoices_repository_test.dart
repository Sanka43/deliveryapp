import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnd_shop/core/constants/firebase_collections.dart';
import 'package:mnd_shop/features/billing/data/vendor_monthly_invoices_repository.dart';
import 'package:mnd_shop/features/billing/domain/vendor_monthly_invoice.dart';

void main() {
  group('VendorMonthlyInvoicesRepository', () {
    test('returns empty stream when vendor id is blank', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final MockFirebaseAuth auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'vendor-1'),
      );
      final VendorMonthlyInvoicesRepository repo =
          VendorMonthlyInvoicesRepository(firestore: firestore, auth: auth);

      final List<VendorMonthlyInvoice> invoices =
          await repo.watchInvoices('').first;

      expect(invoices, isEmpty);
    });

    test('returns invoices for owned vendor doc', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final MockFirebaseAuth auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'vendor-1'),
      );
      await firestore.collection(FirebaseCollections.vendors).doc('vendor-1').set(
        <String, dynamic>{'uid': 'vendor-1', 'name': 'Test Shop'},
      );
      await firestore
          .collection(FirebaseCollections.vendors)
          .doc('vendor-1')
          .collection(FirebaseCollections.vendorMonthlyInvoices)
          .doc('2026-07')
          .set(<String, dynamic>{
            'monthKey': '2026-07',
            'netSalesLkr': 50000,
            'feePercent': 5,
            'feeLkr': 2500,
            'status': 'invoiced',
          });

      final VendorMonthlyInvoicesRepository repo =
          VendorMonthlyInvoicesRepository(firestore: firestore, auth: auth);

      final List<VendorMonthlyInvoice> invoices =
          await repo.watchInvoices('vendor-1').first;

      expect(invoices, hasLength(1));
      expect(invoices.first.monthKey, '2026-07');
      expect(invoices.first.feeLkr, 2500);
      expect(invoices.first.isInvoiced, isTrue);
    });

    test('blocks invoices for another vendor store', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final MockFirebaseAuth auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'vendor-1'),
      );
      await firestore.collection(FirebaseCollections.vendors).doc('store-2').set(
        <String, dynamic>{'uid': 'other-user', 'name': 'Other Shop'},
      );

      final VendorMonthlyInvoicesRepository repo =
          VendorMonthlyInvoicesRepository(firestore: firestore, auth: auth);

      final List<VendorMonthlyInvoice> invoices =
          await repo.watchInvoices('store-2').first;

      expect(invoices, isEmpty);
    });
  });
}
