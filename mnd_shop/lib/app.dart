import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/app/navigation/root_navigator_key.dart';
import 'package:mnd_shop/app/providers/locale_provider.dart';
import 'package:mnd_shop/app/providers/shop_auth_state_provider.dart';
import 'package:mnd_shop/app/providers/theme_mode_provider.dart';
import 'package:mnd_shop/app/widgets/app_update_gate.dart';
import 'package:mnd_shop/app/widgets/shop_push_notification_bootstrap.dart';
import 'package:mnd_shop/core/locale/app_language_option.dart';
import 'package:mnd_shop/core/theme/app_theme.dart';
import 'package:mnd_shop/core/utils/user_facing_error.dart';
import 'package:mnd_shop/core/widgets/vendor_shell_ui.dart';
import 'package:mnd_shop/features/auth/presentation/pages/shop_login_page.dart';
import 'package:mnd_shop/features/auth/presentation/pages/vendor_account_gate_page.dart';
import 'package:mnd_shop/features/dashboard/presentation/pages/vendor_shell_page.dart';
import 'package:mnd_shop/features/orders/presentation/widgets/vendor_incoming_order_snackbar_host.dart';
import 'package:mnd_shop/features/products/presentation/providers/vendor_session_store_providers.dart';

class MndShopApp extends ConsumerWidget {
  const MndShopApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<User?> auth = ref.watch(shopAuthStateProvider);
    final AsyncValue<ThemeMode> themeAsync = ref.watch(themeModeProvider);
    final ThemeMode themeMode = themeAsync.valueOrNull ?? ThemeMode.light;
    final Locale? locale = ref.watch(appLocaleProvider).valueOrNull;

    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'MND Vendor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: kAppSupportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (BuildContext context, Widget? child) {
        final Brightness brightness = Theme.of(context).brightness;
        final bool dark = brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                dark ? Brightness.light : Brightness.dark,
            statusBarBrightness: dark ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarIconBrightness:
                dark ? Brightness.light : Brightness.dark,
            systemNavigationBarContrastEnforced: false,
          ),
          child: VendorResponsiveAppFrame(
            child: AppUpdateGate(child: child ?? const SizedBox.shrink()),
          ),
        );
      },
      home: auth.when(
        data: (User? user) {
          if (user == null) {
            return const ShopLoginPage();
          }
          return Consumer(
            builder: (BuildContext context, WidgetRef ref, _) {
              final String storeKey = ref.watch(vendorEffectiveStoreIdProvider);
              return Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  const VendorAccountGate(child: VendorShellPage()),
                  const ShopPushNotificationBootstrap(),
                  VendorIncomingOrderSnackbarHost(
                    key: ValueKey<String>(storeKey),
                  ),
                ],
              );
            },
          );
        },
        loading: () => Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Checking your session…',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        error: (Object e, StackTrace _) => Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'We could not verify sign-in status.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    userFacingError(
                      e,
                      fallback: 'Please check your connection and try again.',
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void runMndShopApp() {
  runApp(const ProviderScope(child: MndShopApp()));
}
