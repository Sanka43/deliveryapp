/// Inventory counts for vendor dashboard / hero chips.
class VendorCatalogMetricsSnapshot {
  const VendorCatalogMetricsSnapshot({
    required this.total,
    required this.outCount,
    required this.lowCount,
    required this.activeCount,
  });

  final int total;
  final int outCount;
  final int lowCount;
  final int activeCount;

  static const VendorCatalogMetricsSnapshot empty = VendorCatalogMetricsSnapshot(
    total: 0,
    outCount: 0,
    lowCount: 0,
    activeCount: 0,
  );
}
