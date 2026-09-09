import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/core/locale/app_language_option.dart';
import 'package:mnd_delivery_app/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kLanguagePrefKey = 'app_language_code';

final AsyncNotifierProvider<AppLocaleNotifier, Locale?> appLocaleProvider =
    AsyncNotifierProvider<AppLocaleNotifier, Locale?>(
  AppLocaleNotifier.new,
);

class AppLocaleNotifier extends AsyncNotifier<Locale?> {
  @override
  Future<Locale?> build() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return _readLocale(prefs);
  }

  static Locale? _readLocale(SharedPreferences prefs) {
    final String? code = prefs.getString(_kLanguagePrefKey);
    if (code == null || code.isEmpty || code == 'system') {
      return null;
    }
    return Locale(code);
  }

  /// `null` = use device locale.
  Future<void> setLocale(Locale? locale) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.setString(_kLanguagePrefKey, 'system');
    } else {
      await prefs.setString(_kLanguagePrefKey, locale.languageCode);
    }
    state = AsyncData<Locale?>(locale);
  }

  Future<void> setByOptionId(String id) async {
    if (id == AppLanguageOption.system.id) {
      await setLocale(null);
      return;
    }
    await setLocale(Locale(id));
  }
}

/// Short label for lists (profile tile subtitle).
///
/// Language names are shown in their own script/language regardless of the
/// current locale (matching [AppLanguageOption]'s picker labels) — only the
/// "device default" chrome text is translated.
String describeAppLocaleChoice(BuildContext context, Locale? explicit) {
  if (explicit == null) {
    return AppLocalizations.of(context).languageDeviceDefault;
  }
  switch (explicit.languageCode) {
    case 'en':
      return 'English';
    case 'si':
      return 'සිංහල';
    case 'ta':
      return 'தமிழ்';
    default:
      return explicit.languageCode;
  }
}
