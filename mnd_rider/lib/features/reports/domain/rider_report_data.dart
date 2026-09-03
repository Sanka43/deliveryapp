import 'package:mnd_rider/features/earnings/data/rider_cash_repository.dart';
import 'package:mnd_rider/features/earnings/domain/rider_transaction.dart';
import 'package:mnd_rider/features/earnings/domain/rider_withdrawal.dart';
import 'package:mnd_rider/features/orders/domain/rider_order_detail.dart';
import 'package:mnd_rider/features/trips/data/rider_trips_repository.dart';

/// Everything needed to render the rider's report for one date range —
/// pulled fresh (not from the capped live streams) so a report always
/// reflects the exact range the rider picked.
class RiderReportData {
  const RiderReportData({
    required this.start,
    required this.end,
    required this.deliveries,
    required this.trips,
    required this.transactions,
    required this.withdrawals,
    required this.cashEntries,
    required this.cashSettlements,
  });

  const RiderReportData.empty({required this.start, required this.end})
      : deliveries = const <RiderOrderDetail>[],
        trips = const <RiderPassengerTrip>[],
        transactions = const <RiderTransaction>[],
        withdrawals = const <RiderWithdrawal>[],
        cashEntries = const <RiderCashEntry>[],
        cashSettlements = const <RiderCashSettlement>[];

  final DateTime start;
  final DateTime end;
  final List<RiderOrderDetail> deliveries;
  final List<RiderPassengerTrip> trips;
  final List<RiderTransaction> transactions;
  final List<RiderWithdrawal> withdrawals;
  final List<RiderCashEntry> cashEntries;
  final List<RiderCashSettlement> cashSettlements;

  List<RiderPassengerTrip> get completedTrips => trips
      .where((RiderPassengerTrip t) => t.status.toLowerCase() == 'completed')
      .toList(growable: false);

  int get deliveryCount => deliveries.length;
  int get tripCount => completedTrips.length;
  int get totalJobCount => deliveryCount + tripCount;

  double get deliveryEarningsLkr => deliveries.fold(
        0.0,
        (double s, RiderOrderDetail o) => s + o.deliveryFeeLkr,
      );

  double get rideEarningsLkr => completedTrips.fold(
        0.0,
        (double s, RiderPassengerTrip t) => s + t.estimatedFareLkr,
      );

  double get totalEarningsLkr => deliveryEarningsLkr + rideEarningsLkr;

  int get cashCollectedLkr =>
      cashEntries.fold(0, (int s, RiderCashEntry e) => s + e.cashLkr);
  int get cashOwedLkr =>
      cashEntries.fold(0, (int s, RiderCashEntry e) => s + e.owedLkr);
  int get productCashLkr =>
      cashEntries.fold(0, (int s, RiderCashEntry e) => s + e.productCashLkr);
  int get serviceChargeLkr => cashEntries.fold(
        0,
        (int s, RiderCashEntry e) => s + e.serviceChargeLkr,
      );
  int get rideCommissionLkr => cashEntries.fold(
        0,
        (int s, RiderCashEntry e) => s + e.rideCommissionLkr,
      );

  /// What the rider kept from cash jobs after handing over what's owed.
  int get keptCashEarningLkr => cashCollectedLkr - cashOwedLkr;

  int get settledCashLkr => cashSettlements
      .where((RiderCashSettlement s) => s.status == 'confirmed')
      .fold(0, (int sum, RiderCashSettlement s) => sum + s.amountLkr);

  double get withdrawnLkr => withdrawals
      .where((RiderWithdrawal w) => w.status == RiderWithdrawalStatus.paid)
      .fold(0.0, (double s, RiderWithdrawal w) => s + w.amountLkr);

  double get pendingWithdrawalLkr => withdrawals
      .where((RiderWithdrawal w) => w.status == RiderWithdrawalStatus.pending)
      .fold(0.0, (double s, RiderWithdrawal w) => s + w.amountLkr);

  bool get isEmpty =>
      deliveries.isEmpty &&
      trips.isEmpty &&
      transactions.isEmpty &&
      withdrawals.isEmpty &&
      cashEntries.isEmpty &&
      cashSettlements.isEmpty;

  /// Deliveries + completed rides as one list, newest first — the single
  /// source of truth for both the PDF history table and the in-app preview,
  /// so the two never disagree on ordering.
  List<RiderReportHistoryEntry> get historyEntries {
    final List<RiderReportHistoryEntry> entries = <RiderReportHistoryEntry>[
      for (final RiderOrderDetail o in deliveries)
        RiderReportHistoryEntry(
          isRide: false,
          reference: o.trackingNumber?.trim().isNotEmpty == true
              ? o.trackingNumber!.trim()
              : o.id,
          title: o.storeName,
          amountLkr: o.deliveryFeeLkr.toDouble(),
          at: o.createdAt?.toLocal(),
        ),
      for (final RiderPassengerTrip t in completedTrips)
        RiderReportHistoryEntry(
          isRide: true,
          reference: t.id.length > 8 ? t.id.substring(0, 8) : t.id,
          title: t.pickupLabel.isEmpty ? 'Passenger ride' : t.pickupLabel,
          amountLkr: t.estimatedFareLkr.toDouble(),
          at: t.createdAt?.toLocal(),
        ),
    ];
    entries.sort((RiderReportHistoryEntry a, RiderReportHistoryEntry b) {
      if (a.at == null && b.at == null) {
        return 0;
      }
      if (a.at == null) {
        return 1;
      }
      if (b.at == null) {
        return -1;
      }
      return b.at!.compareTo(a.at!);
    });
    return entries;
  }
}

/// One row of [RiderReportData.historyEntries] — a delivery or a ride,
/// flattened to what the report needs to display.
class RiderReportHistoryEntry {
  const RiderReportHistoryEntry({
    required this.isRide,
    required this.reference,
    required this.title,
    required this.amountLkr,
    required this.at,
  });

  final bool isRide;
  final String reference;
  final String title;
  final double amountLkr;
  final DateTime? at;
}

/// Carries the report + rider identity across the route to the preview
/// screen, since the PDF isn't built until that screen actually renders.
class RiderReportPreviewArgs {
  const RiderReportPreviewArgs({
    required this.data,
    required this.riderName,
    required this.riderPhone,
    required this.vehicleNumber,
  });

  final RiderReportData data;
  final String riderName;
  final String riderPhone;
  final String vehicleNumber;
}
