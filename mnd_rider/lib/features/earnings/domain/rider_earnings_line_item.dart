enum RiderEarningsItemKind { delivery, ride }

class RiderEarningsLineItem {
  const RiderEarningsLineItem({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.kind,
    required this.completedAt,
  });

  final String title;
  final String subtitle;
  final double amount;
  final RiderEarningsItemKind kind;
  final DateTime completedAt;
}
