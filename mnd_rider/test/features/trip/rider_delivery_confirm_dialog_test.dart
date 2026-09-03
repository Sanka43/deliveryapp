import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnd_rider/features/trip/presentation/widgets/rider_delivery_confirm_dialog.dart';

Future<void> _pumpDialog(
  WidgetTester tester, {
  required int collectAmountLkr,
  bool isPrepaidOnline = false,
  bool awayFromDropoff = false,
  List<RiderCollectLine> breakdown = const <RiderCollectLine>[],
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: RiderDeliveryConfirmDialog(
          collectAmountLkr: collectAmountLkr,
          isPrepaidOnline: isPrepaidOnline,
          awayFromDropoff: awayFromDropoff,
          breakdown: breakdown,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

bool _confirmEnabled(WidgetTester tester) {
  final FilledButton button = tester.widget<FilledButton>(
    find.widgetWithText(FilledButton, 'Confirm delivered'),
  );
  return button.onPressed != null;
}

void main() {
  testWidgets('cash order needs the payment button before confirming', (
    WidgetTester tester,
  ) async {
    await _pumpDialog(tester, collectAmountLkr: 1737);

    expect(find.text('Rs. 1737'), findsOneWidget);
    expect(find.text('Confirm Rs. 1737 received'), findsOneWidget);
    expect(_confirmEnabled(tester), isFalse);

    await tester.tap(find.text('Confirm Rs. 1737 received'));
    await tester.pumpAndSettle();

    expect(find.text('Payment received'), findsOneWidget);
    expect(_confirmEnabled(tester), isTrue);

    // Tapping again clears a mis-tap and locks confirmation back down.
    await tester.tap(find.text('Payment received'));
    await tester.pumpAndSettle();
    expect(_confirmEnabled(tester), isFalse);
  });

  testWidgets('prepaid order skips the payment gate', (
    WidgetTester tester,
  ) async {
    await _pumpDialog(
      tester,
      collectAmountLkr: 0,
      isPrepaidOnline: true,
    );

    expect(find.textContaining('Already paid online'), findsOneWidget);
    expect(find.textContaining('received'), findsNothing);
    expect(_confirmEnabled(tester), isTrue);
  });

  testWidgets('shows the breakdown and the away-from-dropoff warning', (
    WidgetTester tester,
  ) async {
    await _pumpDialog(
      tester,
      collectAmountLkr: 1737,
      awayFromDropoff: true,
      breakdown: const <RiderCollectLine>[
        RiderCollectLine(label: 'Products', amountLkr: 1300),
        RiderCollectLine(label: 'Delivery', amountLkr: 437),
      ],
    );

    expect(
      find.textContaining('do not appear to be at the drop-off'),
      findsOneWidget,
    );
    expect(find.text('Products'), findsOneWidget);
    expect(find.text('Rs. 1300'), findsOneWidget);
    expect(find.text('Rs. 437'), findsOneWidget);
  });
}
