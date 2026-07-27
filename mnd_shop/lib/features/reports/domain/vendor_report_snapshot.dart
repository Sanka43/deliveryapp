class DailySalesPoint {
  const DailySalesPoint({
    required this.shortLabel,
    required this.dateKey,
    required this.grossLkr,
    required this.orders,
    this.cancelledOrders = 0,
  });

  final String shortLabel;
  final String dateKey;
  final double grossLkr;
  final int orders;
  final int cancelledOrders;
}

class ProductSalesPoint {
  const ProductSalesPoint({
    required this.productKey,
    required this.productName,
    required this.quantity,
    required this.grossLkr,
    required this.completedOrders,
  });

  final String productKey;
  final String productName;
  final int quantity;
  final double grossLkr;
  final int completedOrders;
}

class VendorReportSnapshot {
  const VendorReportSnapshot({
    required this.last7Days,
    required this.categoryLabels,
    required this.categoryValuesLkr,
    this.productRows = const <ProductSalesPoint>[],
    this.grossLkr = 0,
    this.netSalesLkr = 0,
    this.discountLkr = 0,
    this.deliveryFeeLkr = 0,
    this.completedOrders = 0,
    this.cancelledOrders = 0,
    this.rangeLabel = 'Last 7 days',
  });

  final List<DailySalesPoint> last7Days;
  final List<String> categoryLabels;
  final List<double> categoryValuesLkr;
  final List<ProductSalesPoint> productRows;
  final double grossLkr;
  final double netSalesLkr;
  final double discountLkr;
  final double deliveryFeeLkr;
  final int completedOrders;
  final int cancelledOrders;
  final String rangeLabel;

  static final VendorReportSnapshot empty = VendorReportSnapshot(
    last7Days: List<DailySalesPoint>.generate(
      7,
      (int i) => DailySalesPoint(
        shortLabel: const <String>[
          'Mon',
          'Tue',
          'Wed',
          'Thu',
          'Fri',
          'Sat',
          'Sun',
        ][i],
        dateKey: '',
        grossLkr: 0,
        orders: 0,
      ),
    ),
    categoryLabels: const <String>['No product sales yet'],
    categoryValuesLkr: const <double>[0],
  );

  double get totalCategoryLkr {
    double s = 0;
    for (final double v in categoryValuesLkr) {
      s += v;
    }
    return s;
  }

  bool get hasSalesData {
    if (grossLkr > 0 || totalCategoryLkr > 0) {
      return true;
    }
    for (final DailySalesPoint day in last7Days) {
      if (day.grossLkr > 0 || day.orders > 0 || day.cancelledOrders > 0) {
        return true;
      }
    }
    return false;
  }

  double get averageOrderValueLkr =>
      completedOrders <= 0 ? 0 : grossLkr / completedOrders;

  double get cancellationRatePercent {
    final int total = completedOrders + cancelledOrders;
    return total <= 0 ? 0 : (cancelledOrders / total) * 100;
  }

  ProductSalesPoint? get bestSellingProduct {
    if (productRows.isEmpty) {
      return null;
    }
    final List<ProductSalesPoint> rows = productRows.toList(growable: false)
      ..sort((ProductSalesPoint a, ProductSalesPoint b) {
        final int revenue = b.grossLkr.compareTo(a.grossLkr);
        return revenue != 0 ? revenue : b.quantity.compareTo(a.quantity);
      });
    return rows.first;
  }
}
