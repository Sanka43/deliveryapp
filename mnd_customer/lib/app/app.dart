import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/app/providers/locale_provider.dart';
import 'package:mnd_delivery_app/app/router/app_router.dart';
import 'package:mnd_delivery_app/core/locale/app_language_option.dart';
import 'package:mnd_delivery_app/app/widgets/customer_app_lifecycle.dart';
import 'package:mnd_delivery_app/core/config/env_config.dart';
import 'package:mnd_delivery_app/core/theme/app_theme.dart';

class MndDeliveryApp extends ConsumerWidget {
  const MndDeliveryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(appRouterProvider);
    final AsyncValue<Locale?> localeState = ref.watch(appLocaleProvider);

    return CustomerAppLifecycle(
      child: MaterialApp.router(
      title: EnvConfig.appTitle,
      debugShowCheckedModeBanner: EnvConfig.showDebugBanner,
      routerConfig: router,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      locale: localeState.when(
        data: (Locale? l) => l,
        loading: () => null,
        error: (_, __) => null,
      ),
      supportedLocales: kAppSupportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
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