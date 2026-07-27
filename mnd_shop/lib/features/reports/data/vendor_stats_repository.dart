import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/app/providers/firebase_providers.dart';
import 'package:mnd_shop/core/constants/firebase_collections.dart';
import 'package:mnd_shop/features/reports/domain/vendor_report_snapshot.dart';

final Provider<VendorStatsRepository> vendorStatsRepositoryProvider =
    Provider<VendorStatsRepository>((Ref ref) {
      return VendorStatsRepository(firestore: ref.watch(firestoreProvider));
    });

enum VendorAnalyticsPreset { today, week, month, year, custom }

class VendorAnalyticsRange {
  const VendorAnalyticsRange({
    required this.preset,
    required this.start,
    required this.end,
  });

  final VendorAnalyticsPreset preset;
  final DateTime start;
  final DateTime end;

  factory VendorAnalyticsRange.forPreset(
    VendorAnalyticsPreset preset, {
    DateTime? now,
  }) {
    final DateTime clock = (now ?? DateTime.now()).toUtc();
    final DateTime today = DateTime.utc(clock.year, clock.month, clock.day);
    return switch (preset) {
      VendorAnalyticsPreset.today => VendorAnalyticsRange(
        preset: preset,
        start: today,
        end: today,
      ),
      VendorAnalyticsPreset.week => VendorAnalyticsRange(
        preset: preset,
        start: today.subtract(Duration(days: today.weekday - 1)),
        end: today,
      ),
      VendorAnalyticsPreset.month => VendorAnalyticsRange(
        preset: preset,
        start: DateTime.utc(today.year, today.month),
        end: today,
      ),
      VendorAnalyticsPreset.year => VendorAnalyticsRange(
        preset: preset,
        start: DateTime.utc(today.year),
        end: today,
      ),
      VendorAnalyticsPreset.custom => VendorAnalyticsRange(
        preset: VendorAnalyticsPreset.month,
        start: DateTime.utc(today.year, today.month),
        end: today,
      ),
    };
  }

  VendorAnalyticsRange custom(DateTime startDate, DateTime endDate) {
    return VendorAnalyticsRange(
      preset: VendorAnalyticsPreset.custom,
      start: DateTime.utc(startDate.year, startDate.month, startDate.day),
      end: DateTime.utc(endDate.year, endDate.month, endDate.day),
    );
  }

  String get startKey => _dateKey(start);
  String get endKey => _dateKey(end);

  String get label {
    return switch (preset) {
      VendorAnalyticsPreset.today => 'Today',
      VendorAnalyticsPreset.week => 'This week',
      VendorAnalyticsPreset.month => 'This month',
      VendorAnalyticsPreset.year => 'This year',
      VendorAnalyticsPreset.custom => '$startKey to $endKey',
    };
  }

  @override
  bool operator ==(Object other) {
    return other is VendorAnalyticsRange &&
        other.preset == preset &&
        other.startKey == startKey &&
        other.endKey == endKey;
  }

  @override
  int get hashCode => Object.hash(preset, startKey, endKey);

  static String _dateKey(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }
}

class VendorStatsRequest {
  const VendorStatsRequest({required this.vendorId, required this.range});

  final String vendorId;
  final VendorAnalyticsRange range;

  @override
  bool operator ==(Object other) {
    return other is VendorStatsRequest &&
        other.vendorId == vendorId &&
        other.range == range;
  }

  @override
  int get hashCode => Object.hash(vendorId, range);
}

class VendorStatsRepository {
  VendorStatsRepository({required FirebaseFirestore firestore})
    : _firestore = firestore;

  final FirebaseFirestore _firestore;

  Stream<VendorReportSnapshot> watchReportSnapshot(String vendorId) {
    return watchAnalyticsSnapshot(
      VendorStatsRequest(
        vendorId: vendorId,
        range: VendorAnalyticsRange.forPreset(VendorAnalyticsPreset.week),
      ),
    );
  }

  Stream<VendorReportSnapshot> watchAnalyticsSnapshot(
    VendorStatsRequest request,
  ) {
    final String id = request.vendorId.trim();
    if (id.isEmpty) {
      return Stream<VendorReportSnapshot>.value(VendorReportSnapshot.empty);
    }
    final DocumentReference<Map<String, dynamic>> vendorRef = _firestore
        .collection(FirebaseCollections.vendors)
        .doc(id);

    return vendorRef
        .collection(FirebaseCollections.vendorDailyStats)
        .where('date', isGreaterThanOrEqualTo: request.range.startKey)
        .where('date', isLessThanOrEqualTo: request.range.endKey)
        .orderBy('date')
        .snapshots()
        .asyncMap((QuerySnapshot<Map<String, dynamic>> dailySnap) async {
          final QuerySnapshot<Map<String, dynamic>> productSnap =
              await vendorRef
                  .collection(FirebaseCollections.vendorProductDailyStats)
                  .where('date', isGreaterThanOrEqualTo: request.range.startKey)
                  .where('date', isLessThanOrEqualTo: request.range.endKey)
                  .orderBy('date')
                  .get();
          return _fromRangeSnapshots(
            range: request.range,
            dailyDocs: dailySnap.docs,
            productDocs: productSnap.docs,
          );
        });
  }

  static VendorReportSnapshot _fromRangeSnapshots({
    required VendorAnalyticsRange range,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> dailyDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> productDocs,
  }) {
    final Map<String, Map<String, dynamic>> dailyByDate =
        <String, Map<String, dynamic>>{
          for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
              in dailyDocs)
            (doc.data()['date'] as String?)?.trim() ?? doc.id: doc.data(),
        };

    final List<DailySalesPoint> chart = <DailySalesPoint>[];
    double gross = 0;
    double net = 0;
    double discount = 0;
    double delivery = 0;
    int completed = 0;
    int cancelled = 0;

    for (
      DateTime day = range.start;
      !day.isAfter(range.end);
      day = day.add(const Duration(days: 1))
    ) {
      final String key = _dateKey(day);
      final Map<String, dynamic>? row = dailyByDate[key];
      final double dayGross = _readShopSales(row);
      final int dayCompleted = _readInt(row?['completedOrders']);
      final int dayCancelled = _readInt(row?['cancelledOrders']);
      gross += dayGross;
      net += dayGross;
      discount += _readDouble(row?['discountLkr']);
      delivery += _readDouble(row?['deliveryFeeLkr']);
      completed += dayCompleted;
      cancelled += dayCancelled;
      chart.add(
        DailySalesPoint(
          shortLabel: _chartLabel(day, range),
          dateKey: key,
          grossLkr: dayGross,
          orders: dayCompleted,
          cancelledOrders: dayCancelled,
        ),
      );
    }

    final Map<String, ProductSalesPoint> products =
        <String, ProductSalesPoint>{};
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in productDocs) {
      final Map<String, dynamic> row = doc.data();
      final String key =
          ((row['productKey'] as String?)?.trim().isNotEmpty == true
          ? row['productKey'] as String
          : doc.id);
      final ProductSalesPoint previous =
          products[key] ??
          ProductSalesPoint(
            productKey: key,
            productName:
                (row['productName'] as String?)?.trim().isNotEmpty == true
                ? row['productName'] as String
                : 'Order item',
            quantity: 0,
            grossLkr: 0,
            completedOrders: 0,
          );
      products[key] = ProductSalesPoint(
        productKey: previous.productKey,
        productName: previous.productName,
        quantity: previous.quantity + _readInt(row['quantity']),
        grossLkr: previous.grossLkr + _readDouble(row['grossLkr']),
        completedOrders:
            previous.completedOrders + _readInt(row['completedOrders']),
      );
    }

    final List<ProductSalesPoint> productRows = products.values.toList()
      ..sort((ProductSalesPoint a, ProductSalesPoint b) {
        final int byRevenue = b.grossLkr.compareTo(a.grossLkr);
        return byRevenue != 0 ? byRevenue : b.quantity.compareTo(a.quantity);
      });
    final List<ProductSalesPoint> topRows = productRows
        .take(6)
        .toList(growable: false);

    return VendorReportSnapshot(
      last7Days: chart,
      categoryLabels: topRows.isEmpty
          ? const <String>['No product sales yet']
          : <String>[
              for (final ProductSalesPoint row in topRows) row.productName,
            ],
      categoryValuesLkr: topRows.isEmpty
          ? const <double>[0]
          : <double>[for (final ProductSalesPoint row in topRows) row.grossLkr],
      productRows: productRows,
      grossLkr: gross,
      netSalesLkr: net,
      discountLkr: discount,
      deliveryFeeLkr: delivery,
      completedOrders: completed,
      cancelledOrders: cancelled,
      rangeLabel: range.label,
    );
  }

  static String _chartLabel(DateTime day, VendorAnalyticsRange range) {
    if (range.preset == VendorAnalyticsPreset.year) {
      return '${day.month}/${day.day}';
    }
    return const <String>[
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ][day.weekday - 1];
  }

  static String _dateKey(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  static double _readDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _readShopSales(Map<String, dynamic>? row) {
    if (row == null) {
      return 0;
    }
    if (row.containsKey('netSalesLkr')) {
      return _readDouble(row['netSalesLkr']);
    }
    final double gross = _readDouble(row['grossLkr']);
    final double delivery = _readDouble(row['deliveryFeeLkr']);
    return math.max(0, gross - delivery);
  }

  static int _readInt(Object? value) {
    if (value is num) {
      return value.round();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
