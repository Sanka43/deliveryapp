/// One completed (or cancelled) delivery / ride row for history.
enum RiderHistoryKind { delivery, ride }

class RiderDeliveryHistoryItem {
  const RiderDeliveryHistoryItem({
    required this.orderId,
    required this.completedAtLabel,
    required this.routeSummary,
    required this.pickupLabel,
    required this.dropoffLabel,
    required this.payout,
    required this.completed,
    this.trackingNumber,
    this.completedAt,
    this.kind = RiderHistoryKind.delivery,
  });

  final String orderId;
  final String completedAtLabel;
  final String routeSummary;
  final String pickupLabel;
  final String dropoffLabel;
  final double payout;
  final bool completed;
  final String? trackingNumber;
  final DateTime? completedAt;
  final RiderHistoryKind kind;

  String get referenceForDisplay {
    final String? t = trackingNumber?.trim();
    if (t != null && t.isNotEmpty) {
      return t;
    }
    return kind == RiderHistoryKind.ride ? 'Ride' : '—';
  }
}
