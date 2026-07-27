import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnd_shop/core/constants/firebase_collections.dart';
import 'package:mnd_shop/features/reports/data/vendor_stats_repository.dart';

void main() {
  group('VendorAnalyticsRange', () {
    test('week preset starts on Monday and ends today in UTC', () {
      final VendorAnalyticsRange range = VendorAnalyticsRange.forPreset(
        VendorAnalyticsPreset.week,
        now: DateTime.utc(2026, 7, 14, 12),
      );

      expect(range.startKey, '2026-07-13');
      expect(range.endKey, '2026-07-14');
      expect(range.label, 'This week');
    });

    test('custom range normalizes dates and label', () {
      final VendorAnalyticsRange base = VendorAnalyticsRange.forPreset(
        VendorAnalyticsPreset.month,
        now: DateTime.utc(2026, 7, 14),
      );
      final VendorAnalyticsRange custom = base.custom(
        DateTime(2026, 7, 10, 20),
        DateTime(2026, 7, 12, 8),
      );

      expect(custom.startKey, '2026-07-10');
      expect(custom.endKey, '2026-07-12');
      expect(custom.label, '2026-07-10 to 2026-07-12');
    });
  });

  group('VendorStatsRepository', () {
    test('aggregates daily and product stats over selected range', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final VendorStatsRepository repo = VendorStatsRepository(
        firestore: firestore,
      );
      final vendor = firestore
          .collection(FirebaseCollections.vendors)
          .doc('store-1');

      await vendor
          .collection(FirebaseCollections.vendorDailyStats)
          .add(<String, dynamic>{
            'date': '2026-07-13',
            'grossLkr': 1000,
            'netSalesLkr': 900,
            'discountLkr': 100,
            'deliveryFeeLkr': 150,
            'completedOrders': 2,
            'cancelledOrders': 1,
          });
      await vendor
          .collection(FirebaseCollections.vendorProductDailyStats)
          .add(<String, dynamic>{
            'date': '2026-07-13',
            'productKey': 'rice',
            'productName': 'Rice',
            'quantity': 3,
            'grossLkr': 1200,
            'completedOrders': 2,
          });

      final snapshot = await repo
          .watchAnalyticsSnapshot(
            VendorStatsRequest(
              vendorId: 'store-1',
              range: VendorAnalyticsRange.forPreset(
                VendorAnalyticsPreset.week,
                now: DateTime.utc(2026, 7, 14),
              ),
            ),
          )
          .first;

      expect(snapshot.grossLkr, 900);
      expect(snapshot.netSalesLkr, 900);
      expect(snapshot.last7Days.first.grossLkr, 900);
      expect(snapshot.completedOrders, 2);
      expect(snapshot.cancelledOrders, 1);
      expect(snapshot.productRows.single.productName, 'Rice');
      expect(snapshot.bestSellingProduct?.productKey, 'rice');
    });

    test(
      'falls back to gross minus delivery fee when net sales are absent',
      () async {
        final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
        final VendorStatsRepository repo = VendorStatsRepository(
          firestore: firestore,
        );
        final vendor = firestore
            .collection(FirebaseCollections.vendors)
            .doc('store-2');

        await vendor
            .collection(FirebaseCollections.vendorDailyStats)
            .add(<String, dynamic>{
              'date': '2026-07-13',
              'grossLkr': 1250,
              'deliveryFeeLkr': 200,
              'completedOrders': 1,
            });

        final snapshot = await repo
            .watchAnalyticsSnapshot(
              VendorStatsRequest(
                vendorId: 'store-2',
                range: VendorAnalyticsRange.forPreset(
                  VendorAnalyticsPreset.week,
                  now: DateTime.utc(2026, 7, 14),
                ),
              ),
            )
            .first;

        expect(snapshot.grossLkr, 1050);
        expect(snapshot.netSalesLkr, 1050);
        expect(snapshot.last7Days.first.grossLkr, 1050);
      },
    );
  });
}
