import 'package:flutter_test/flutter_test.dart';
import 'package:mnd_delivery_app/features/orders/domain/order_tracking_number.dart';

void main() {
  group('OrderTrackingNumber.build', () {
    test('formats MND + YY + 5-digit sequence', () {
      final DateTime d = DateTime(2026, 5, 14);
      expect(OrderTrackingNumber.build(placedAt: d, sequence: 12), 'MND2600012');
    });

    test('pads single-digit year and sequence', () {
      final DateTime d = DateTime(2007, 1, 1);
      expect(OrderTrackingNumber.build(placedAt: d, sequence: 1), 'MND0700001');
    });

    test('rejects non-positive sequence', () {
      expect(
        () => OrderTrackingNumber.build(placedAt: DateTime(2026), sequence: 0),
        throwsArgumentError,
      );
    });
  });
}
