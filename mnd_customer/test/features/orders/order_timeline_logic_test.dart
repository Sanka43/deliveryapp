import 'package:flutter_test/flutter_test.dart';
import 'package:mnd_delivery_app/features/orders/domain/order_timeline.dart';

void main() {
  group('OrderTimelineLogic', () {
    test('currentPhaseIndex advances through pipeline', () {
      expect(OrderTimelineLogic.currentPhaseIndex('placed'), 0);
      expect(OrderTimelineLogic.currentPhaseIndex('confirmed'), 1);
      expect(OrderTimelineLogic.currentPhaseIndex('preparing'), 2);
      expect(OrderTimelineLogic.currentPhaseIndex('ready'), 3);
      expect(OrderTimelineLogic.currentPhaseIndex('out_for_delivery'), 4);
      expect(OrderTimelineLogic.currentPhaseIndex('on_the_way'), 4);
      expect(OrderTimelineLogic.currentPhaseIndex('delivered'), 5);
    });

    test('isCancelled detects cancelled status', () {
      expect(OrderTimelineLogic.isCancelled('cancelled'), isTrue);
      expect(OrderTimelineLogic.isCancelled('placed'), isFalse);
    });

    test('isActiveForLiveRiderMap excludes terminal states', () {
      expect(OrderTimelineLogic.isActiveForLiveRiderMap('preparing'), isTrue);
      expect(OrderTimelineLogic.isActiveForLiveRiderMap('delivered'), isFalse);
      expect(OrderTimelineLogic.isActiveForLiveRiderMap('cancelled'), isFalse);
    });
  });
}
