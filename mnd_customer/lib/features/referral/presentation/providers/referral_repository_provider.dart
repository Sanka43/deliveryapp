import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/features/referral/data/referral_repository.dart';

final Provider<ReferralRepository> referralRepositoryProvider =
    Provider<ReferralRepository>((Ref ref) {
  return ReferralRepository();
});
