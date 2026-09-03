import 'package:flutter_test/flutter_test.dart';
import 'package:mnd_shop/features/dashboard/domain/vendor_sales_summary.dart';
import 'package:mnd_shop/features/dashboard/domain/vendor_pending_order.dart';
import 'package:mnd_shop/features/orders/data/vendor_orders_repository.dart';
import 'package:mnd_shop/features/reports/data/vendor_stats_repository.dart';
import 'package:mnd_shop/features/reports/domain/vendor_report_aggregator.dart';
import 'package:mnd_shop/features/reports/domain/vendor_report_snapshot.dart';

void main() {
  group('VendorReportAggregator', () {
    test('aggregates completed and cancelled orders in selected range', () {
      final DateTime now = DateTime.utc(2026, 7, 14, 12);
      final VendorAnalyticsRange range = VendorAnalyticsRange.forPreset(
        VendorAnalyticsPreset.week,
        now: now,
      );
      final VendorOrderBoard board = VendorOrderBoard(
        incoming: const <VendorPendingOrder>[],
        kitchen: const <VendorPendingOrder>[],
        readyForPickup: const <VendorPendingOrder>[],
        outForDelivery: const <VendorPendingOrder>[],
        completed: <VendorPendingOrder>[
          VendorPendingOrder(
            id: 'o1',
            customerPhone: '+94771234567',
            itemsSummary: 'Rice',
            itemLines: const <String>['1× Rice'],
            items: const <VendorOrderLineItem>[
              VendorOrderLineItem(
                productKey: 'rice',
                productName: 'Rice',
                quantity: 2,
                lineTotal: 1000,
              ),
            ],
            total: 1200,
            deliveryFee: 200,
            subtotal: 1000,
            placedAtLabel: 'Today',
            createdAt: DateTime.utc(2026, 7, 13, 10),
            statusKey: 'completed',
          ),
        ],
        cancelled: <VendorPendingOrder>[
          VendorPendingOrder(
            id: 'o2',
            customerPhone: '+94771234567',
            itemsSummary: 'Tea',
            itemLines: const <String>['1× Tea'],
            total: 300,
            placedAtLabel: 'Today',
            createdAt: DateTime.utc(2026, 7, 13, 11),
            statusKey: 'cancelled',
          ),
        ],
        salesSummary: VendorSalesSummary.zero,
      );

      final VendorReportSnapshot snapshot = VendorReportAggregator.fromOrderBoard(
        board,
        now: now,
        range: range,
      );

      expect(snapshot.completedOrders, 1);
      expect(snapshot.cancelledOrders, 1);
      expect(snapshot.grossLkr, 1000);
      expect(snapshot.productRows, hasLength(1));
      expect(snapshot.productRows.first.productName, 'Rice');
      expect(snapshot.productRows.first.quantity, 2);
    });

    test('ignores terminal orders outside the selected range', () {
      final DateTime now = DateTime.utc(2026, 7, 14, 12);
      final VendorAnalyticsRange range = VendorAnalyticsRange.forPreset(
        VendorAnalyticsPreset.today,
        now: now,
      );
      final VendorOrderBoard board = VendorOrderBoard(
        incoming: const <VendorPendingOrder>[],
        kitchen: const <VendorPendingOrder>[],
        readyForPickup: const <VendorPendingOrder>[],
        outForDelivery: const <VendorPendingOrder>[],
        completed: <VendorPendingOrder>[
          VendorPendingOrder(
            id: 'old',
            customerPhone: '',
            itemsSummary: 'Old',
            itemLines: const <String>['1× Old'],
            total: 500,
            subtotal: 500,
            placedAtLabel: 'Old',
            createdAt: DateTime.utc(2026, 7, 1),
            statusKey: 'completed',
          ),
        ],
        cancelled: const <VendorPendingOrder>[],
        salesSummary: VendorSalesSummary.zero,
      );

      final VendorReportSnapshot snapshot = VendorReportAggregator.fromOrderBoard(
        board,
        now: now,
        range: range,
      );

      expect(snapshot.completedOrders, 0);
      expect(snapshot.grossLkr, 0);
    });
  });
}
