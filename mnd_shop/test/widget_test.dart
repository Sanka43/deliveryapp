import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/app.dart';
import 'package:mnd_shop/app/providers/shop_auth_state_provider.dart';

void main() {
  testWidgets('Vendor app shows sign-in when logged out', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          shopAuthStateProvider.overrideWith(
            (Ref ref) => Stream<User?>.value(null),
          ),
        ],
        child: const MndShopApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vendor app'), findsOneWidget);
    expect(find.text('Sign in'), findsWidgets);
  });
}
