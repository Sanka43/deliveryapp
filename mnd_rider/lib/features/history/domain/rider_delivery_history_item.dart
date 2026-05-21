/// One completed (or cancelled) delivery row for history.
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
  });

  final String orderId;
  final String completedAtLabel;
  final String routeSummary;
  final String pickupLabel;
  final String dropoffLabel;
  final double payout;
  final bool completed;
  final String? trackingNumber;

  String get referenceForDisplay {
    final String? t = trackingNumber?.trim();
    if (t != null && t.isNotEmpty) {
      return t;
    }
    return '—';
  }
}
