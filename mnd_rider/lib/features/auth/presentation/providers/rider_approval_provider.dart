import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_rider/features/auth/domain/rider_profile_document.dart';
import 'package:mnd_rider/features/auth/presentation/providers/rider_registration_provider.dart';

/// True when admin has approved this rider (`status` is approved/active).
final Provider<bool> riderIsApprovedToDriveProvider = Provider<bool>((Ref ref) {
  final RiderProfileDocument? profile =
      ref.watch(riderAuthProfileProvider).valueOrNull;
  return profile?.isApprovedToDrive ?? false;
});

final Provider<bool> riderIsPendingApprovalProvider = Provider<bool>((Ref ref) {
  final RiderProfileDocument? profile =
      ref.watch(riderAuthProfileProvider).valueOrNull;
  if (profile == null) {
    return false;
  }
  return profile.isPendingApproval;
});
