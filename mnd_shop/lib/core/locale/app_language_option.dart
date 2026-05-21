import 'package:flutter/material.dart';

/// Built-in language choices for the vendor app.
class AppLanguageOption {
  const AppLanguageOption._({
    required this.id,
    required this.title,
    this.subtitle,
  });

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

  static const List<AppLanguageOption> ordered = <AppLanguageOption>[
    system,
    english,
    sinhala,
  ];

  final String id;
  final String title;
  final String? subtitle;

  bool get isSystem => id == 'system';
}

const List<Locale> kAppSupportedLocales = <Locale>[
  Locale('en'),
  Locale('si'),
];
