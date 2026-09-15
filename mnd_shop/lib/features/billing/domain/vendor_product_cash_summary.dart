/// Aggregate view of a shop's cash-on-delivery (COD) money across the four
/// stages tracked by `orders.productCashStatus` (owed by the rider ->
/// remittance requested -> with admin -> settled to the shop). Read-only —
/// this ledger is server-authoritative and admin-settled, same as
/// `VendorWallet` is for online-paid orders (see vendor_wallet.dart).
class VendorProductCashSummary {
  const VendorProductCashSummary({
    this.owedLkr = 0,
    this.owedCount = 0,
    this.requestedLkr = 0,
    this.requestedCount = 0,
    this.withAdminLkr = 0,
    this.withAdminCount = 0,
    this.settledLkr = 0,
    this.settledCount = 0,
  });

  /// Cash the rider is still holding (`productCashStatus == 'owed'`).
  final double owedLkr;
  final int owedCount;

  /// Rider asked admin to confirm a handover (`remittance_requested`).
  final double requestedLkr;
  final int requestedCount;

  /// Admin has the cash, not yet paid to the shop (`remitted_to_admin`).
  final double withAdminLkr;
  final int withAdminCount;

  /// Lifetime total already paid to the shop (`settled_to_shop`).
  final double settledLkr;
  final int settledCount;

  static const VendorProductCashSummary zero = VendorProductCashSummary();
}
