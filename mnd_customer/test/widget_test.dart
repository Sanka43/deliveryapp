import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/app/app.dart';
import 'package:mnd_delivery_app/app/providers/locale_provider.dart';
import 'package:mnd_delivery_app/app/router/app_router.dart';

void main() {
  testWidgets('App boot smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appLocaleProvider.overrideWith(_TestAppLocale.new),
          appRouterProvider.overrideWithValue(
            GoRouter(
              initialLocation: '/login',
              routes: <RouteBase>[
                GoRoute(
                  path: '/login',
                  builder: (BuildContext context, GoRouterState state) {
                    return const Scaffold(
                      body: Center(child: Text('Login')),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
        child: const MndDeliveryApp(),
      ),
    );

    expect(find.text('Login'), findsOneWidget);
  });
}

class _TestAppLocale extends AppLocaleNotifier {
  @override
  Future<Locale?> build() async => null;
}
