import 'package:flutter_test/flutter_test.dart';
import 'package:mnd_shop/features/reports/data/vendor_stats_repository.dart';
import 'package:mnd_shop/features/reports/domain/vendor_report_pdf_builder.dart';
import 'package:mnd_shop/features/reports/domain/vendor_report_snapshot.dart';

void main() {
  group('VendorReportPdfBuilder', () {
    test('builds a non-empty PDF document for a snapshot', () async {
      final VendorReportSnapshot snapshot = VendorReportSnapshot(
        last7Days: <DailySalesPoint>[
          DailySalesPoint(
            dateKey: '2026-07-13',
            shortLabel: 'Mon',
            grossLkr: 1500,
            orders: 2,
          ),
        ],
        categoryLabels: <String>['Rice'],
        categoryValuesLkr: <double>[1500],
        productRows: <ProductSalesPoint>[
          ProductSalesPoint(
            productKey: 'rice',
            productName: 'Rice',
            quantity: 3,
            grossLkr: 1500,
            completedOrders: 2,
          ),
        ],
        grossLkr: 1500,
        netSalesLkr: 1400,
        discountLkr: 100,
        deliveryFeeLkr: 200,
        completedOrders: 2,
        cancelledOrders: 0,
        rangeLabel: 'This week',
      );

      final pdf = VendorReportPdfBuilder.build(
        data: snapshot,
        mnd: const MndReportParty(
          name: 'MND Delivery',
          phone: '+94 77 637 6869',
        ),
        shop: const ShopReportParty(
          name: 'Test Shop',
          city: 'Kandy',
        ),
        insights: const <String>['Rice is leading this range with 3 sold.'],
        inventoryActive: 4,
        inventoryLow: 1,
        inventoryOut: 0,
      );

      final List<int> bytes = await pdf.save();
      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });
  });
}
