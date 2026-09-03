import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnd_shop/features/dashboard/domain/vendor_pending_order.dart';
import 'package:mnd_shop/features/orders/presentation/widgets/vendor_item_variant_chip.dart';
import 'package:mnd_shop/features/orders/presentation/widgets/vendor_order_items_list.dart';

const List<VendorOrderLineItem> _items = <VendorOrderLineItem>[
  VendorOrderLineItem(
    productKey: 'cheese-koththu',
    productName: 'Cheese Koththu',
    quantity: 2,
    lineTotal: 1600,
    selectedSize: 'Chicken · Full',
    extras: <String>['Extra cheese'],
  ),
];

Future<void> _pumpList(WidgetTester tester, {required bool emphasize}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: VendorOrderItemsList(
          items: _items,
          primaryText: Colors.black,
          mutedText: Colors.grey,
          emphasizeVariants: emphasize,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('detail-page mode shows the size and add-ons as chips', (
    WidgetTester tester,
  ) async {
    await _pumpList(tester, emphasize: true);

    expect(find.text('Cheese Koththu'), findsOneWidget);
    // `Chicken · Full` splits into a food-type badge plus the size chip.
    expect(find.text('Chicken'), findsOneWidget);
    expect(
      find.widgetWithText(VendorItemVariantChip, 'Full'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(VendorItemVariantChip, 'Extra cheese'),
      findsOneWidget,
    );
  });

  testWidgets('preview mode keeps the compact muted size line', (
    WidgetTester tester,
  ) async {
    await _pumpList(tester, emphasize: false);

    expect(find.text('Full'), findsOneWidget);
    expect(find.byType(VendorItemVariantChip), findsNothing);
    expect(find.text('Extra cheese'), findsNothing);
  });
}
