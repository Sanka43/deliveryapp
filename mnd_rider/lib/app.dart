import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_rider/app/providers/theme_mode_provider.dart';
import 'package:mnd_rider/core/router/app_router.dart';
import 'package:mnd_rider/core/theme/app_theme.dart';

class MndRiderApp extends ConsumerWidget {
  const MndRiderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(appRouterProvider);
    final AsyncValue<ThemeMode> themeAsync = ref.watch(themeModeProvider);
    final ThemeMode themeMode = themeAsync.valueOrNull ?? ThemeMode.light;

    return MaterialApp.router(
      title: 'MND Rider',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}

void runMndRiderApp() {
  runApp(
    const ProviderScope(
      child: MndRiderApp(),
    ),
  );
}
