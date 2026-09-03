import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_rider/core/services/rider_location_service.dart';
import 'package:mnd_rider/features/auth/presentation/providers/rider_approval_provider.dart';
import 'package:mnd_rider/features/presence/data/rider_presence_repository.dart';
import 'package:mnd_rider/features/profile/data/rider_profile_repository.dart';

/// Earnings aggregates (filled from delivered orders via [riderEarningsSummaryProvider]).
class RiderEarningsSummary {
  const RiderEarningsSummary({
    required this.todayNet,
    required this.weekNet,
    required this.monthNet,
    required this.tripsToday,
    required this.tripsWeek,
    required this.tripsMonth,
  });

  const RiderEarningsSummary.empty()
      : todayNet = 0,
        weekNet = 0,
        monthNet = 0,
        tripsToday = 0,
        tripsWeek = 0,
        tripsMonth = 0;

  final double todayNet;
  final double weekNet;
  final double monthNet;
  final int tripsToday;
  final int tripsWeek;
  final int tripsMonth;
}

class RiderDashboardState {
  const RiderDashboardState({
    required this.isOnline,
    required this.earnings,
  });

  final bool isOnline;
  final RiderEarningsSummary earnings;

  RiderDashboardState copyWith({
    bool? isOnline,
    RiderEarningsSummary? earnings,
  }) {
    return RiderDashboardState(
      isOnline: isOnline ?? this.isOnline,
      earnings: earnings ?? this.earnings,
    );
  }
}

class RiderDashboardNotifier extends Notifier<RiderDashboardState> {
  @override
  RiderDashboardState build() {
    return const RiderDashboardState(
      isOnline: false,
      earnings: RiderEarningsSummary.empty(),
    );
  }

  /// Returns a user-visible error when going online is not allowed.
  Future<String?> setOnline(bool value) async {
    if (value && !ref.read(riderIsApprovedToDriveProvider)) {
      return 'Your account is waiting for admin approval. You cannot go online yet.';
    }
    if (value) {
      final profile = ref.read(riderProfileStreamProvider).asData?.value;
      if (profile != null && profile.hasExpiredDrivingDocs) {
        return 'Insurance or revenue license has expired. Renew documents before going online.';
      }
      final String? locationError =
          await ref.read(riderLocationServiceProvider).ensureLocationReady();
      if (locationError != null) {
        return locationError;
      }
      // Confirm GPS publishing actually came up before writing presence —
      // otherwise a rider can show as online in Firestore with no live
      // location stream behind it (permission revoked in this exact window,
      // GPS hardware error, etc.).
      final bool trackingStarted =
          await ref.read(riderLocationServiceProvider).setTrackingEnabled(true);
      if (!trackingStarted) {
        return 'Could not start location tracking. Check location permission and try again.';
      }
    }
    state = state.copyWith(isOnline: value);
    try {
      await ref.read(riderPresenceRepositoryProvider).setOnline(value);
      return null;
    } catch (e) {
      state = state.copyWith(isOnline: !value);
      return 'Could not update online status. Check your connection and try again.';
    }
  }

  /// Sync toggle from Firestore without writing presence again.
  void syncOnlineFromRemote(bool value) {
    if (state.isOnline != value) {
      state = state.copyWith(isOnline: value);
      // Keep the heartbeat aligned so the server dead-man sweep doesn't
      // flip a genuinely-online rider offline (e.g. after app restart).
      final RiderPresenceRepository presence =
          ref.read(riderPresenceRepositoryProvider);
      if (value) {
        presence.startHeartbeat();
      } else {
        presence.stopHeartbeat();
      }
    }
  }

  /// Call when backend delivers fresh aggregates.
  void setEarnings(RiderEarningsSummary summary) {
    state = state.copyWith(earnings: summary);
  }
}

final riderDashboardProvider =
    NotifierProvider<RiderDashboardNotifier, RiderDashboardState>(
  RiderDashboardNotifier.new,
);
