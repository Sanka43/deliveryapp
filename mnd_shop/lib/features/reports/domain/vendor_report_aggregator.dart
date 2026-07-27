import 'dart:math' as math;

import 'package:mnd_shop/features/dashboard/domain/vendor_pending_order.dart';
import 'package:mnd_shop/features/orders/data/vendor_orders_repository.dart';
import 'package:mnd_shop/features/orders/domain/vendor_order_status.dart';
import 'package:mnd_shop/features/reports/data/vendor_stats_repository.dart';
import 'package:mnd_shop/features/reports/domain/vendor_report_snapshot.dart';

/// Builds report data from the live order board when server stats are empty.
abstract final class VendorReportAggregator {
  static const List<String> _weekdayLabels = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  static VendorReportSnapshot fromOrderBoard(
    VendorOrderBoard board, {
    DateTime? now,
    VendorAnalyticsRange? range,
  }) {
    final DateTime clock = (now ?? DateTime.now()).toUtc();
    final DateTime todayUtc = DateTime.utc(clock.year, clock.month, clock.day);
    final VendorAnalyticsRange selectedRange =
        range ??
        VendorAnalyticsRange(
          preset: VendorAnalyticsPreset.week,
          start: todayUtc.subtract(const Duration(days: 6)),
          end: todayUtc,
        );

    // Match Cloud Functions dayKey() / Firestore daily_stats `date` (UTC).
    final List<DailySalesPoint> dailyPoints =
        selectedRange.preset == VendorAnalyticsPreset.today
        ? _hourlyPoints(board, selectedRange.startKey)
        : _dailyPoints(board, selectedRange);

    final Map<String, double> productRevenue = <String, double>{};
    final Map<String, int> productQty = <String, int>{};
    final Map<String, int> productCompleted = <String, int>{};
    final Map<String, String> productNames = <String, String>{};
    int completedOrders = 0;
    int cancelledOrders = 0;
    double grossLkr = 0;

    for (final VendorPendingOrder order in _terminalOrders(board)) {
      final DateTime? at = order.createdAt;
      if (at == null || !_inUtcRange(at, selectedRange)) {
        continue;
      }
      if (VendorOrderStatus.isCompleted(order.statusKey)) {
        completedOrders++;
        grossLkr += order.shopTotal;
        _allocateProductRevenue(
          productRevenue,
          productQty,
          productCompleted,
          productNames,
          order,
        );
      } else if (VendorOrderStatus.isCancelled(order.statusKey)) {
        cancelledOrders++;
      }
    }

    final List<MapEntry<String, double>> ranked =
        productRevenue.entries.toList(growable: false)
          ..sort((MapEntry<String, double> a, MapEntry<String, double> b) {
            final int byRevenue = b.value.compareTo(a.value);
            return byRevenue != 0
                ? byRevenue
                : (productQty[b.key] ?? 0).compareTo(productQty[a.key] ?? 0);
          });

    final List<ProductSalesPoint> productRows = ranked
        .map(
          (MapEntry<String, double> row) => ProductSalesPoint(
            productKey: row.key,
            productName: productNames[row.key] ?? row.key,
            quantity: productQty[row.key] ?? 0,
            grossLkr: row.value,
            completedOrders: productCompleted[row.key] ?? 0,
          ),
        )
        .toList(growable: false);

    final List<String> categoryLabels = <String>[];
    final List<double> categoryValuesLkr = <double>[];
    double other = 0;
    for (int i = 0; i < ranked.length; i++) {
      final MapEntry<String, double> entry = ranked[i];
      if (i < 5) {
        categoryLabels.add(entry.key);
        categoryLabels[categoryLabels.length - 1] =
            productNames[entry.key] ?? entry.key;
        categoryValuesLkr.add(entry.value);
      } else {
        other += entry.value;
      }
    }
    if (other > 0) {
      categoryLabels.add('Other');
      categoryValuesLkr.add(other);
    }
    if (categoryLabels.isEmpty) {
      categoryLabels.add('No product sales yet');
      categoryValuesLkr.add(0);
    }

    return VendorReportSnapshot(
      last7Days: dailyPoints,
      categoryLabels: categoryLabels,
      categoryValuesLkr: categoryValuesLkr,
      productRows: productRows,
      grossLkr: grossLkr,
      netSalesLkr: grossLkr,
      completedOrders: completedOrders,
      cancelledOrders: cancelledOrders,
      rangeLabel: selectedRange.label,
    );
  }

  static Iterable<VendorPendingOrder> _terminalOrders(VendorOrderBoard board) {
    return <VendorPendingOrder>[...board.completed, ...board.cancelled];
  }

  static List<DailySalesPoint> _hourlyPoints(
    VendorOrderBoard board,
    String dayKey,
  ) {
    final List<String> parts = dayKey.split('-');
    final DateTime dayStartUtc = DateTime.utc(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
    return List<DailySalesPoint>.generate(24, (int hour) {
      final DateTime hourStart = dayStartUtc.add(Duration(hours: hour));
      final DateTime hourEnd = hourStart.add(const Duration(hours: 1));
      double gross = 0;
      int completed = 0;
      int cancelled = 0;

      for (final VendorPendingOrder order in _terminalOrders(board)) {
        final DateTime? at = order.createdAt?.toUtc();
        if (at == null || at.isBefore(hourStart) || !at.isBefore(hourEnd)) {
          continue;
        }
        if (VendorOrderStatus.isCompleted(order.statusKey)) {
          gross += order.shopTotal;
          completed++;
        } else if (VendorOrderStatus.isCancelled(order.statusKey)) {
          cancelled++;
        }
      }

      return DailySalesPoint(
        shortLabel: '${hour.toString().padLeft(2, '0')}:00',
        dateKey: '$dayKey ${hour.toString().padLeft(2, '0')}:00',
        grossLkr: gross,
        orders: completed,
        cancelledOrders: cancelled,
      );
    });
  }

  static List<DailySalesPoint> _dailyPoints(
    VendorOrderBoard board,
    VendorAnalyticsRange range,
  ) {
    final List<DailySalesPoint> points = <DailySalesPoint>[];
    for (
      DateTime day = range.start;
      !day.isAfter(range.end);
      day = day.add(const Duration(days: 1))
    ) {
      final String key = _utcDateKey(day);
      double gross = 0;
      int completed = 0;
      int cancelled = 0;

      for (final VendorPendingOrder order in _terminalOrders(board)) {
        final DateTime? at = order.createdAt;
        if (at == null || _utcDateKey(at) != key) {
          continue;
        }
        if (VendorOrderStatus.isCompleted(order.statusKey)) {
          gross += order.shopTotal;
          completed++;
        } else if (VendorOrderStatus.isCancelled(order.statusKey)) {
          cancelled++;
        }
      }

      points.add(
        DailySalesPoint(
          shortLabel: _chartLabel(day, range),
          dateKey: key,
          grossLkr: gross,
          orders: completed,
          cancelledOrders: cancelled,
        ),
      );
    }
    return points;
  }

  static bool _inUtcRange(DateTime at, VendorAnalyticsRange range) {
    final String key = _utcDateKey(at);
    return key.compareTo(range.startKey) >= 0 &&
        key.compareTo(range.endKey) <= 0;
  }

  static String _utcDateKey(DateTime value) {
    final DateTime utc = value.toUtc();
    return '${utc.year.toString().padLeft(4, '0')}-'
        '${utc.month.toString().padLeft(2, '0')}-'
        '${utc.day.toString().padLeft(2, '0')}';
  }

  static void _allocateProductRevenue(
    Map<String, double> revenueOut,
    Map<String, int> qtyOut,
    Map<String, int> completedOut,
    Map<String, String> productNames,
    VendorPendingOrder order,
  ) {
    if (order.items.isNotEmpty) {
      final Set<String> seenInOrder = <String>{};
      for (final VendorOrderLineItem item in order.items) {
        final String key = _safeProductKey(item.productKey, item.productName);
        final double revenue = item.lineTotal > 0
            ? item.lineTotal
            : order.shopTotal * (item.quantity / math.max(1, order.itemCount));
        productNames[key] = item.productName;
        _addProduct(
          revenueOut,
          qtyOut,
          completedOut,
          name: key,
          revenue: revenue,
          qty: item.quantity,
          completedOrders: seenInOrder.add(key) ? 1 : 0,
        );
      }
      return;
    }

    if (order.itemLines.isEmpty) {
      _addProduct(
        revenueOut,
        qtyOut,
        completedOut,
        name: 'Order items',
        revenue: order.shopTotal,
        qty: order.itemCount,
        completedOrders: 1,
      );
      return;
    }

    int totalQty = 0;
    final List<({String name, int qty})> parsed = <({String name, int qty})>[];
    for (final String line in order.itemLines) {
      final ({String name, int qty})? item = _parseLine(line);
      if (item == null) {
        continue;
      }
      parsed.add(item);
      totalQty += item.qty;
    }

    if (parsed.isEmpty || totalQty <= 0) {
      _addProduct(
        revenueOut,
        qtyOut,
        completedOut,
        name: 'Order items',
        revenue: order.shopTotal,
        qty: order.itemCount,
        completedOrders: 1,
      );
      return;
    }

    for (final ({String name, int qty}) item in parsed) {
      _addProduct(
        revenueOut,
        qtyOut,
        completedOut,
        name: item.name,
        revenue: order.shopTotal * (item.qty / totalQty),
        qty: item.qty,
        completedOrders: 1,
      );
    }
  }

  static void _addProduct(
    Map<String, double> revenueOut,
    Map<String, int> qtyOut,
    Map<String, int> completedOut, {
    required String name,
    required double revenue,
    required int qty,
    required int completedOrders,
  }) {
    revenueOut.update(
      name,
      (double value) => value + revenue,
      ifAbsent: () => revenue,
    );
    qtyOut.update(name, (int value) => value + qty, ifAbsent: () => qty);
    completedOut.update(
      name,
      (int value) => value + completedOrders,
      ifAbsent: () => completedOrders,
    );
  }

  static ({String name, int qty})? _parseLine(String line) {
    final RegExp flexiblePattern = RegExp(r'^(\d+)\D+(.+)$');
    final RegExpMatch? flexibleMatch = flexiblePattern.firstMatch(line.trim());
    if (flexibleMatch != null) {
      final int? qty = int.tryParse(flexibleMatch.group(1)!);
      final String name = flexibleMatch.group(2)!.trim();
      if (qty != null && qty > 0 && name.isNotEmpty) {
        return (name: name, qty: qty);
      }
    }
    final RegExp pattern = RegExp(r'^(\d+)\s*(?:x|Ã—|×)\s*(.+)$');
    final RegExpMatch? match = pattern.firstMatch(line.trim());
    if (match == null) {
      return null;
    }
    final int? qty = int.tryParse(match.group(1)!);
    final String name = match.group(2)!.trim();
    if (qty == null || qty <= 0 || name.isEmpty) {
      return null;
    }
    return (name: name, qty: qty);
  }

  static String _safeProductKey(String productKey, String productName) {
    final String key = productKey.trim();
    if (key.isNotEmpty) {
      return key;
    }
    final String name = productName.trim();
    return name.isEmpty ? 'Order item' : name;
  }

  static String _chartLabel(DateTime day, VendorAnalyticsRange range) {
    if (range.preset == VendorAnalyticsPreset.year) {
      return '${day.month}/${day.day}';
    }
    return _weekdayLabels[day.weekday - 1];
  }
}
