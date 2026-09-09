import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/features/cart/data/coupon_repository.dart';

final Provider<CouponRepository> couponRepositoryProvider =
    Provider<CouponRepository>((Ref ref) {
  return CouponRepository();
});
