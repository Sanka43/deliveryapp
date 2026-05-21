import 'package:cloud_firestore/cloud_firestore.dart';

/// `riders/{riderId}/wallet/summary`
class RiderWallet {
  const RiderWallet({
    required this.balanceLkr,
    required this.pendingWithdrawalLkr,
    required this.lifetimeEarnedLkr,
    required this.lifetimeWithdrawnLkr,
    this.updatedAt,
  });

  const RiderWallet.empty()
      : balanceLkr = 0,
        pendingWithdrawalLkr = 0,
        lifetimeEarnedLkr = 0,
        lifetimeWithdrawnLkr = 0,
        updatedAt = null;

  final double balanceLkr;
  final double pendingWithdrawalLkr;
  final double lifetimeEarnedLkr;
  final double lifetimeWithdrawnLkr;
  final DateTime? updatedAt;

  double get availableToWithdrawLkr => balanceLkr;

  factory RiderWallet.fromMap(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) {
      return const RiderWallet.empty();
    }
    return RiderWallet(
      balanceLkr: _readDouble(data['balanceLkr']),
      pendingWithdrawalLkr: _readDouble(data['pendingWithdrawalLkr']),
      lifetimeEarnedLkr: _readDouble(data['lifetimeEarnedLkr']),
      lifetimeWithdrawnLkr: _readDouble(data['lifetimeWithdrawnLkr']),
      updatedAt: _readTimestamp(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'balanceLkr': balanceLkr,
      'pendingWithdrawalLkr': pendingWithdrawalLkr,
      'lifetimeEarnedLkr': lifetimeEarnedLkr,
      'lifetimeWithdrawnLkr': lifetimeWithdrawnLkr,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static double _readDouble(dynamic value) {
    if (value is int) {
      return value.toDouble();
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _readTimestamp(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    return null;
  }
}
