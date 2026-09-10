/// Server-authoritative payout balance under `vendors/{vendorId}/wallet/summary`.
///
/// Credited by the `onOrderCompletedCreditVendor` Cloud Function when an
/// online-paid order is completed/delivered, debited by `requestVendorPayout`.
/// Cash-on-delivery sales are settled separately via the admin-run
/// `productCashStatus` ledger on each order, not through this wallet.
class VendorWallet {
  const VendorWallet({
    this.balanceLkr = 0,
    this.pendingWithdrawalLkr = 0,
    this.lifetimeEarnedLkr = 0,
    this.lifetimeWithdrawnLkr = 0,
  });

  /// Available to withdraw right now.
  final double balanceLkr;

  /// Locked in payout requests awaiting admin settlement.
  final double pendingWithdrawalLkr;

  final double lifetimeEarnedLkr;
  final double lifetimeWithdrawnLkr;

  static const VendorWallet zero = VendorWallet();

  factory VendorWallet.fromFirestore(Map<String, dynamic>? data) {
    if (data == null) {
      return VendorWallet.zero;
    }
    return VendorWallet(
      balanceLkr: _readDouble(data['balanceLkr']),
      pendingWithdrawalLkr: _readDouble(data['pendingWithdrawalLkr']),
      lifetimeEarnedLkr: _readDouble(data['lifetimeEarnedLkr']),
      lifetimeWithdrawnLkr: _readDouble(data['lifetimeWithdrawnLkr']),
    );
  }

  static double _readDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
