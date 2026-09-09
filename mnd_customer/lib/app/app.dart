import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/app/providers/locale_provider.dart';
import 'package:mnd_delivery_app/app/router/app_router.dart';
import 'package:mnd_delivery_app/core/locale/app_language_option.dart';
import 'package:mnd_delivery_app/app/widgets/customer_app_lifecycle.dart';
import 'package:mnd_delivery_app/app/widgets/app_update_gate.dart';
import 'package:mnd_delivery_app/core/config/env_config.dart';
import 'package:mnd_delivery_app/core/theme/app_theme.dart';
import 'package:mnd_delivery_app/features/auth/presentation/providers/guest_browsing_provider.dart';
import 'package:mnd_delivery_app/features/auth/presentation/providers/user_role_provider.dart';
import 'package:mnd_delivery_app/l10n/generated/app_localizations.dart';

class MndDeliveryApp extends ConsumerWidget {
  const MndDeliveryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(appRouterProvider);
    final AsyncValue<Locale?> localeState = ref.watch(appLocaleProvider);

    // Keep role + guest persistence subscribed for the app lifetime.
    ref.watch(userRolePersistenceProvider);
    ref.watch(guestBrowsingPersistenceProvider);

    return CustomerAppLifecycle(
      child: MaterialApp.router(
        title: EnvConfig.appTitle,
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        theme: AppTheme.lightTheme,
        // Belt-and-suspenders: even if something requests dark, keep light UI.
        darkTheme: AppTheme.lightTheme,
        // Customer UI hardcodes light palette (AppColors.textPrimary, white scaffolds).
        // System dark mode was making menus/inputs unreadable — keep the app light.
        themeMode: ThemeMode.light,
        builder: (BuildContext context, Widget? child) {
          final MediaQueryData mq = MediaQuery.of(context);
          // Localizations.localeOf is the final resolved locale (post
          // localeResolutionCallback), unlike the possibly-null value this
          // widget passes to MaterialApp's own `locale:` below.
          final Locale resolvedLocale = Localizations.localeOf(context);
          return Theme(
            data: AppTheme.applyLocalizedFont(Theme.of(context), resolvedLocale),
            child: MediaQuery(
              data: mq.copyWith(platformBrightness: Brightness.light),
              child: AppUpdateGate(child: child ?? const SizedBox.shrink()),
            ),
          );
        },
        locale: localeState.when(
          data: (Locale? l) => l,
          loading: () => null,
          error: (_, __) => null,
        ),
        supportedLocales: kAppSupportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        localeResolutionCallback: (Locale? locale, Iterable<Locale> supported) {
          if (locale == null) {
            return const Locale('en');
          }
          for (final Locale s in supported) {
            if (s.languageCode == locale.languageCode) {
              return s;
            }
          }
          return const Locale('en');
        },
      ),
    );
  }
}
