import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_rider/features/profile/data/rider_profile_repository.dart';
import 'package:mnd_rider/features/profile/domain/rider_profile.dart';

/// True while the rider is holding more collected cash than
/// `platform_config/fees.maxRiderCashInHandLkr` allows.
///
/// Firestore rules are what actually block a claim (`riderCashHoldActive()`);
/// this provider exists so the app can hide offers and explain why, instead
/// of letting a rider tap Accept and get a bare permission error.
final Provider<bool> riderCashHoldActiveProvider = Provider<bool>((Ref ref) {
  final RiderProfile? profile =
      ref.watch(riderProfileStreamProvider).valueOrNull;
  return profile?.isCashHeld ?? false;
});

/// What the rider must hand to admin to get moving again.
final Provider<int> riderCashOwedProvider = Provider<int>((Ref ref) {
  final RiderProfile? profile =
      ref.watch(riderProfileStreamProvider).valueOrNull;
  return profile?.cashOwedToAdminLkr ?? 0;
});
