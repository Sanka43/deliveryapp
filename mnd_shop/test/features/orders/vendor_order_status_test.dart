import 'package:flutter_test/flutter_test.dart';
import 'package:mnd_shop/features/orders/domain/vendor_order_status.dart';

void main() {
  group('VendorOrderStatus', () {
    test('parses known Firestore keys case-insensitively', () {
      expect(VendorOrderStatus.parse('PLACED'), VendorOrderStatus.placed);
      expect(VendorOrderStatus.parse(' ready '), VendorOrderStatus.ready);
      expect(VendorOrderStatus.parse('unknown'), isNull);
    });

    test('classifies order board buckets', () {
      expect(VendorOrderStatus.isIncoming('placed'), isTrue);
      expect(VendorOrderStatus.isKitchen('confirmed'), isTrue);
      expect(VendorOrderStatus.isKitchen('preparing'), isTrue);
      expect(VendorOrderStatus.isReadyForPickup('ready'), isTrue);
      expect(VendorOrderStatus.isCompleted('completed'), isTrue);
      expect(VendorOrderStatus.isCancelled('cancelled'), isTrue);
    });

    test('opens rider matching only for delivery orders marked ready', () {
      expect(
        VendorOrderStatus.opensRiderMatching(
          status: 'ready',
          fulfillmentMode: 'delivery',
        ),
        isTrue,
      );
      expect(
        VendorOrderStatus.opensRiderMatching(
          status: 'ready',
          fulfillmentMode: 'selfPickup',
        ),
        isFalse,
      );
      expect(
        VendorOrderStatus.opensRiderMatching(
          status: 'completed',
          fulfillmentMode: 'delivery',
        ),
        isFalse,
      );
    });

    test('allows vendor workflow transitions and blocks regressions', () {
      expect(
        VendorOrderStatus.canVendorTransition(from: 'placed', to: 'confirmed'),
        isTrue,
      );
      expect(
        VendorOrderStatus.canVendorTransition(from: 'confirmed', to: 'ready'),
        isTrue,
      );
      expect(
        VendorOrderStatus.canVendorTransition(from: 'ready', to: 'completed'),
        isTrue,
      );
      expect(
        VendorOrderStatus.canVendorTransition(from: 'ready', to: 'confirmed'),
        isFalse,
      );
      expect(
        VendorOrderStatus.canVendorTransition(from: 'completed', to: 'ready'),
        isFalse,
      );
      expect(
        VendorOrderStatus.canVendorTransition(
          from: 'cancelled',
          to: 'confirmed',
        ),
        isFalse,
      );
    });
  });
}
