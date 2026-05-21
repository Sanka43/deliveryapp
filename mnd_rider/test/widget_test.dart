import 'package:flutter_test/flutter_test.dart';
import 'package:mnd_rider/features/orders/domain/rider_order_detail.dart';

void main() {
  test('RiderOrderDetail parses delivery address and fees', () {
    final RiderOrderDetail detail = RiderOrderDetail.fromDoc('ord1', <String, dynamic>{
      'status': 'ready',
      'storeName': 'Test Store',
      'vendorId': 'v1',
      'total': 1500,
      'deliveryFee': 250,
      'trackingNumber': 'MND26001234',
      'deliveryAddress': <String, dynamic>{
        'line1': '12 Main St',
        'line2': '',
        'city': 'Colombo',
        'phone': '0771234567',
      },
      'items': <Map<String, dynamic>>[
        <String, dynamic>{'productName': 'Rice', 'quantity': 2},
      ],
    });

    expect(detail.deliveryFeeLkr, 250);
    expect(detail.dropoffAddressSingleLine, contains('Colombo'));
    expect(detail.itemsSummary, '2 items');
  });
}
