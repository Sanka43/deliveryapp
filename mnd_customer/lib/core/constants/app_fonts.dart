class AppFonts {
  AppFonts._();

  /// App-wide UI (theme).
  static const String primaryFamily = 'Plus Jakarta Sans';

  /// Brand watermark title ("MND").
  static const String brandMarkFamily = 'Bebas Neue';

  /// Caption / meta — maps to labelSmall, labelMedium, bodySmall.
  static const double caption = 12;

  /// Body — maps to bodyMedium, labelLarge.
  static const double body = 14;

  /// Section header / card row title — maps to titleSmall, bodyLarge.
  static const double subtitle = 16;

  /// Page title (AppBar) — maps to titleLarge (w800) and titleMedium (w700).
  static const double title = 20;

  /// Hero / marketing headline only — maps to headline* / display*.
  static const double heading = 24;

  /// Brand mark "MND" display size (Bebas Neue only).
  static const double brandMark = 52;

  /// Brand mark on compact surfaces (onboarding, watermark).
  static const double brandMarkCompact = 42;
}
