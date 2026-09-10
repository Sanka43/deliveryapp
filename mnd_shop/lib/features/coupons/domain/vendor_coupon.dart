import 'package:cloud_firestore/cloud_firestore.dart';

enum VendorCouponDiscountType { flat, percent }

/// `pending` | `approved` | `rejected` — admin reviews every vendor-submitted
/// coupon (mnd_web Coupons page) before it can ever discount a real order.
enum VendorCouponStatus { pending, approved, rejected }

/// A vendor-scoped coupon under top-level `coupons/{code}` (doc id == the
/// code itself, matching `functions/src/coupons.ts`). Only ever created via
/// the `requestVendorCoupon` callable — the client never writes this doc
/// directly except to toggle `active`.
class VendorCoupon {
  const VendorCoupon({
    required this.code,
    required this.discountType,
    required this.value,
    required this.active,
    required this.status,
    this.minSubtotalLkr,
    this.maxDiscountLkr,
    this.expiresAt,
    this.maxUses,
    this.perCustomerLimit,
    this.createdAt,
  });

  final String code;
  final VendorCouponDiscountType discountType;
  final int value;
  final bool active;
  final VendorCouponStatus status;
  final int? minSubtotalLkr;
  final int? maxDiscountLkr;
  final DateTime? expiresAt;
  final int? maxUses;
  final int? perCustomerLimit;
  final DateTime? createdAt;

  bool get isExpired => expiresAt != null && expiresAt!.isBefore(DateTime.now());

  /// Whether this coupon can currently discount a real order — matches the
  /// server's `couponUsableForVendor` gate (status) plus the vendor's own
  /// pause switch (`active`); doesn't re-check usage/min-order limits, which
  /// stay server-side.
  bool get isLive => status == VendorCouponStatus.approved && active && !isExpired;

  String get discountLabel {
    if (discountType == VendorCouponDiscountType.percent) {
      final String cap = maxDiscountLkr != null ? ' (max Rs. $maxDiscountLkr)' : '';
      return '$value% off$cap';
    }
    return 'Rs. $value off';
  }

  factory VendorCoupon.fromFirestore(String code, Map<String, dynamic> data) {
    final String discountTypeRaw = (data['discountType'] as String?)?.trim().toLowerCase() ?? '';
    final String statusRaw = (data['status'] as String?)?.trim().toLowerCase() ?? '';
    return VendorCoupon(
      code: code,
      discountType: discountTypeRaw == 'percent'
          ? VendorCouponDiscountType.percent
          : VendorCouponDiscountType.flat,
      value: _readInt(data['value']),
      active: data['active'] == true,
      status: switch (statusRaw) {
        'approved' => VendorCouponStatus.approved,
        'rejected' => VendorCouponStatus.rejected,
        _ => VendorCouponStatus.pending,
      },
      minSubtotalLkr: _readOptionalInt(data['minSubtotalLkr']),
      maxDiscountLkr: _readOptionalInt(data['maxDiscountLkr']),
      expiresAt: _readDate(data['expiresAt']),
      maxUses: _readOptionalInt(data['maxUses']),
      perCustomerLimit: _readOptionalInt(data['perCustomerLimit']),
      createdAt: _readDate(data['createdAt']),
    );
  }

  static int _readInt(Object? v) {
    if (v is num) {
      return v.round();
    }
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static int? _readOptionalInt(Object? v) {
    if (v == null) {
      return null;
    }
    return _readInt(v);
  }

  static DateTime? _readDate(Object? v) {
    if (v is Timestamp) {
      return v.toDate();
    }
    if (v is DateTime) {
      return v;
    }
    return null;
  }
}
