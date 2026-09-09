import 'package:cloud_functions/cloud_functions.dart';
import 'package:mnd_delivery_app/core/utils/user_facing_error.dart';

class ReferralRedemptionResult {
  const ReferralRedemptionResult._({
    this.couponCode,
    this.discountLkr,
    this.errorMessage,
  });

  factory ReferralRedemptionResult.success({
    required String couponCode,
    required int discountLkr,
  }) {
    return ReferralRedemptionResult._(
      couponCode: couponCode,
      discountLkr: discountLkr,
    );
  }

  factory ReferralRedemptionResult.failure(String message) {
    return ReferralRedemptionResult._(errorMessage: message);
  }

  final String? couponCode;
  final int? discountLkr;
  final String? errorMessage;

  bool get isSuccess => couponCode != null;
}

/// Redeems a referral code via the `redeemReferralCode` Cloud Function —
/// eligibility (new account, code exists, not self-referred) is always
/// decided server-side, same pattern as [CouponRepository].
class ReferralRepository {
  ReferralRepository({FirebaseFunctions? functions})
      : _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'asia-south1');

  final FirebaseFunctions _functions;

  Future<ReferralRedemptionResult> redeem(String code) async {
    final String trimmed = code.trim();
    if (trimmed.isEmpty) {
      return ReferralRedemptionResult.failure('Enter a referral code.');
    }
    try {
      final HttpsCallableResult<dynamic> result = await _functions
          .httpsCallable('redeemReferralCode')
          .call(<String, dynamic>{'code': trimmed});
      final Map<String, dynamic> data =
          Map<String, dynamic>.from(result.data as Map<dynamic, dynamic>);
      if (data['success'] != true) {
        final String? error = (data['error'] as String?)?.trim();
        return ReferralRedemptionResult.failure(
          (error == null || error.isEmpty)
              ? 'Could not apply that referral code.'
              : error,
        );
      }
      return ReferralRedemptionResult.success(
        couponCode: (data['couponCode'] as String?)?.trim() ?? '',
        discountLkr: (data['discountLkr'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      return ReferralRedemptionResult.failure(
        userFacingError(e, fallback: 'Could not apply that referral code.'),
      );
    }
  }
}
