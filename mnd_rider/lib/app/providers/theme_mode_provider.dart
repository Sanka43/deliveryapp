import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kRiderThemeModePrefKey = 'mnd_rider_theme_mode';

final AsyncNotifierProvider<ThemeModeNotifier, ThemeMode> themeModeProvider =
    AsyncNotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends AsyncNotifier<ThemeMode> {
  @override
  Future<ThemeMode> build() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return _parse(prefs.getString(_kRiderThemeModePrefKey));
  }

  ThemeMode _parse(String? raw) {
    if (raw == 'dark') {
      return ThemeMode.dark;
    }
    return ThemeMode.light;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kRiderThemeModePrefKey,
      mode == ThemeMode.dark ? 'dark' : 'light',
    );
    state = AsyncData<ThemeMode>(mode);
  }

  Future<void> toggle() async {
    final ThemeMode current = state.valueOrNull ?? ThemeMode.light;
    await setThemeMode(
      current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
    );
  }
}
