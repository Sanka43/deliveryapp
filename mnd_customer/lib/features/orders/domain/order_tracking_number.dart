/// Human-facing public tracking code: [prefix][YY][sequence padded to 5 digits], e.g. `MND2600012`.
abstract final class OrderTrackingNumber {
  OrderTrackingNumber._();

  static const String prefix = 'MND';

  /// [sequence] is the 1-based monotonic index from Firestore `system/order_sequence.value`.
  static String build({required DateTime placedAt, required int sequence}) {
    if (sequence < 1) {
      throw ArgumentError.value(sequence, 'sequence', 'must be >= 1');
    }
    final int yy = placedAt.year % 100;
    final String yyStr = yy.toString().padLeft(2, '0');
    final String seqStr = sequence.toString().padLeft(5, '0');
    return '$prefix$yyStr$seqStr';
  }
}
