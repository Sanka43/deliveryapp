import 'package:flutter_test/flutter_test.dart';
import 'package:mnd_delivery_app/features/store/domain/product_availability.dart';

void main() {
  group('productAvailabilityFromMap', () {
    test('unmanaged stockQty 0 stays available', () {
      expect(
        productAvailabilityFromMap(<String, dynamic>{
          'stockQty': 0,
        }),
        isTrue,
      );
      expect(
        productAvailabilityFromMap(<String, dynamic>{
          'manageStock': false,
          'stockQty': 0,
        }),
        isTrue,
      );
    });

    test('active false alone does not mark out of stock', () {
      expect(
        productAvailabilityFromMap(<String, dynamic>{
          'active': false,
          'stockQty': 0,
        }),
        isTrue,
      );
    });

    test('isAvailable false alone does not mark out of stock', () {
      expect(
        productAvailabilityFromMap(<String, dynamic>{
          'isAvailable': false,
        }),
        isTrue,
      );
    });

    test('managed stockQty 0 is unavailable', () {
      expect(
        productAvailabilityFromMap(<String, dynamic>{
          'manageStock': true,
          'stockQty': 0,
          'active': true,
        }),
        isFalse,
      );
    });

    test('managed positive stock is available', () {
      expect(
        productAvailabilityFromMap(<String, dynamic>{
          'manageStock': true,
          'stockQty': 3,
          'active': true,
        }),
        isTrue,
      );
    });
  });
}
