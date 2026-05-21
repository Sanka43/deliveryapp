/// Single day row for charts (demo or from analytics API / Firestore later).
class DailySalesPoint {
  const DailySalesPoint({
    required this.shortLabel,
    required this.grossLkr,
    required this.orders,
  });

  final String shortLabel;
  final double grossLkr;
  final int orders;
}

/// Bundle of series used on the vendor reports screen.
class VendorReportSnapshot {
  const VendorReportSnapshot({
    required this.last7Days,
    required this.categoryLabels,
    required this.categoryValuesLkr,
  });

  final List<DailySalesPoint> last7Days;
  final List<String> categoryLabels;
  /// Same length as [categoryLabels]; values ≥ 0.
  final List<double> categoryValuesLkr;

  static VendorReportSnapshot demo() {
    return VendorReportSnapshot(
      last7Days: const <DailySalesPoint>[
        DailySalesPoint(shortLabel: 'Mon', grossLkr: 12400, orders: 8),
        DailySalesPoint(shortLabel: 'Tue', grossLkr: 18200, orders: 11),
        DailySalesPoint(shortLabel: 'Wed', grossLkr: 15600, orders: 9),
        DailySalesPoint(shortLabel: 'Thu', grossLkr: 22100, orders: 14),
        DailySalesPoint(shortLabel: 'Fri', grossLkr: 26800, orders: 16),
        DailySalesPoint(shortLabel: 'Sat', grossLkr: 31200, orders: 19),
        DailySalesPoint(shortLabel: 'Sun', grossLkr: 28900, orders: 17),
      ],
      categoryLabels: const <String>[
        'Mains',
        'Beverages',
        'Sides & snacks',
        'Desserts',
      ],
      categoryValuesLkr: const <double>[
        185000,
        42000,
        38000,
        22000,
      ],
    );
  }

  double get totalCategoryLkr {
    double s = 0;
    for (final double v in categoryValuesLkr) {
      s += v;
    }
    return s;
  }
}
