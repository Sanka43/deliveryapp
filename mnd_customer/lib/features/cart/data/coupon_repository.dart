import 'package:cloud_functions/cloud_functions.dart';
import 'package:mnd_delivery_app/core/utils/user_facing_error.dart';
import 'package:mnd_delivery_app/features/cart/presentation/providers/cart_provider.dart';

class CouponValidationResult {
  const CouponValidationResult._({this.coupon, this.errorMessage});

  factory CouponValidationResult.success(CartCoupon coupon) {
    return CouponValidationResult._(coupon: coupon);
  }

  factory CouponValidationResult.failure(String message) {
    return CouponValidationResult._(errorMessage: message);
  }

  final CartCoupon? coupon;
  final String? errorMessage;

  bool get isSuccess => coupon != null;
}

/// Validates coupon codes against the `validateCoupon` Cloud Function so
/// eligibility (active, not expired, minimum subtotal, usage limits) is
/// always decided server-side rather than trusted from the client.
class CouponRepository {
  CouponRepository({FirebaseFunctions? functions})
      : _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'asia-south1');

  final FirebaseFunctions _functions;

  Future<CouponValidationResult> validate({
    required String code,
    required int subtotalLkr,
    required String storeId,
  }) async {
    final String trimmed = code.trim();
    if (trimmed.isEmpty) {
      return CouponValidationResult.failure('Enter a coupon code.');
    }
    try {
      final HttpsCallableResult<dynamic> result = await _functions
          .httpsCallable('validateCoupon')
          .call(<String, dynamic>{
        'code': trimmed,
        'subtotalLkr': subtotalLkr,
        'storeId': storeId.trim(),
      });
      final Map<String, dynamic> data =
          Map<String, dynamic>.from(result.data as Map<dynamic, dynamic>);
      if (data['valid'] != true) {
        final String? error = (data['error'] as String?)?.trim();
        return CouponValidationResult.failure(
          (error == null || error.isEmpty) ? 'Invalid coupon code.' : error,
        );
      }
      final String returnedCode =
          (data['code'] as String?)?.trim().toUpperCase() ??
              trimmed.toUpperCase();
      final CouponDiscountType discountType =
          (data['discountType'] as String?) == 'percent'
              ? CouponDiscountType.percent
              : CouponDiscountType.flat;
      final int value = (data['value'] as num?)?.toInt() ?? 0;
      return CouponValidationResult.success(
        CartCoupon(
          code: returnedCode,
          discountType: discountType,
          value: value,
        ),
      );
    } catch (e) {
      return CouponValidationResult.failure(
        userFacingError(e, fallback: 'Could not validate coupon.'),
      );
    }
  }
}
