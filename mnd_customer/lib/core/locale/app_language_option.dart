import 'package:flutter/material.dart';

/// Built-in choices for [languageSelectorPageProvider] / UI.
class AppLanguageOption {
  const AppLanguageOption._({
    required this.id,
    required this.title,
    this.subtitle,
  });

  /// Device / system UI language.
  static const AppLanguageOption system = AppLanguageOption._(
    id: 'system',
    title: 'Use device language',
    subtitle: 'Follows your phone settings',
  );

  static const AppLanguageOption english = AppLanguageOption._(
    id: 'en',
    title: 'English',
  );

  static const AppLanguageOption sinhala = AppLanguageOption._(
    id: 'si',
    title: 'සිංහල',
    subtitle: 'Sinhala',
  );

  static const AppLanguageOption tamil = AppLanguageOption._(
    id: 'ta',
    title: 'தமிழ்',
    subtitle: 'Tamil',
  );

  static const List<AppLanguageOption> ordered = <AppLanguageOption>[
    system,
    english,
    sinhala,
    tamil,
  ];

  final String id;
  final String title;
  final String? subtitle;

  bool get isSystem => id == 'system';
}

/// Locales the app can switch to (not including system).
const List<Locale> kAppSupportedLocales = <Locale>[
  Locale('en'),
  Locale('si'),
  Locale('ta'),
];
