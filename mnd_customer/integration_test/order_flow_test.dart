import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mnd_delivery_app/main.dart' as app;

// Drives a customer through: skip onboarding -> phone/OTP login -> Food
// category -> first product -> select variant -> add to cart -> cart ->
// checkout -> pick saved address -> place order -> confirmation.
//
// Requires a Firebase test phone number (fixed OTP, no real SMS) and a test
// account that already has a saved delivery address with a map pin. Pass the
// phone/OTP via --dart-define=DEMO_TEST_PHONE=... --dart-define=DEMO_TEST_OTP=...
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const String testPhone = String.fromEnvironment('DEMO_TEST_PHONE');
  const String testOtp = String.fromEnvironment('DEMO_TEST_OTP');

  testWidgets('customer places an order end-to-end', (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    final Finder skip = find.byKey(const ValueKey<String>('skip'));
    if (skip.evaluate().isNotEmpty) {
      await tester.tap(skip);
      await tester.pumpAndSettle();
    }

    final Finder phoneField = find.byKey(const ValueKey<String>('loginPhoneField'));
    if (phoneField.evaluate().isNotEmpty) {
      await tester.enterText(phoneField, testPhone);
      await tester.tap(find.byKey(const ValueKey<String>('loginContinueButton')));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      for (int i = 0; i < testOtp.length; i++) {
        await tester.enterText(
          find.byKey(ValueKey<String>('otpDigit$i')),
          testOtp[i],
        );
      }
      await tester.tap(find.byKey(const ValueKey<String>('loginVerifyButton')));
      await tester.pumpAndSettle(const Duration(seconds: 3));
    }

    await tester.tap(find.byKey(const ValueKey<String>('homeFoodCategoryTile')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('demoFirstFoodProductCard')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('productDetailFirstTypeOption')));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const ValueKey<String>('addToCartButton')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('viewCartButton')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('proceedToCheckoutButton')));
    await tester.pumpAndSettle();

    final Finder savedAddress =
        find.byKey(const ValueKey<String>('checkoutFirstSavedAddress'));
    if (savedAddress.evaluate().isNotEmpty) {
      await tester.tap(savedAddress);
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byKey(const ValueKey<String>('placeOrderButton')));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.textContaining('Order'), findsWidgets);
  });
}
