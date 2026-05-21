import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kThemeModePrefKey = 'mnd_vendor_theme_mode';

final themeModeProvider =
    AsyncNotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends AsyncNotifier<ThemeMode> {
  @override
  Future<ThemeMode> build() async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    return _parse(p.getString(_kThemeModePrefKey));
  }

  ThemeMode _parse(String? raw) {
    if (raw == 'dark') {
      return ThemeMode.dark;
    }
    return ThemeMode.light;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.setString(
      _kThemeModePrefKey,
      mode == ThemeMode.dark ? 'dark' : 'light',
    );
    state = AsyncData<ThemeMode>(mode);
  }
}
