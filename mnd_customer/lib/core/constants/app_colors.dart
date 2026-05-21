import 'package:flutter/material.dart';

/// MND Customer — premium delivery blue palette.
class AppColors {
  AppColors._();

  static const Color brandPrimary = Color(0xFF0B6EFF);
  static const Color brandPrimaryDark = Color(0xFF0047B3);
  static const Color brandPrimaryLight = Color(0xFF3D9BFF);

  static const Color brandSecondary = Color(0xFF00C2FF);
  static const Color accentPurple = Color(0xFF7C3AED);

  static const Color primaryBlue = brandPrimary;
  static const Color secondaryBlue = brandPrimaryDark;

  /// Home canvas — soft periwinkle blue tint.
  static const Color backgroundCanvas = Color(0xFFF0F6FF);
  static const Color homeBlueTop = Color(0xFFD4E5FF);
  static const Color homeBlueMid = Color(0xFFE6F0FF);
  static const Color homeBlueBottom = Color(0xFFF5F9FF);
  static const Color surface = Color(0xFFFAFAFA);
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color homeMutedFill = Color(0xFFF1F5F9);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);

  static const Color lightBackground = surface;
  static const Color darkBackground = Color(0xFF0B1220);

  static const Color cartBarBackground = Color(0xFF0B1220);

  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color offerOrange = Color(0xFFF97316);
  static const Color error = Color(0xFFDC2626);

  /// Product card circular add button (reference UI).
  static const Color productAddLime = Color(0xFFD4F534);

  static const double cardRadiusSm = 16;
  static const double cardRadiusMd = 20;
  static const double cardRadiusLg = 24;

  static const LinearGradient brandGradient = LinearGradient(
    colors: <Color>[brandPrimary, brandPrimaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient headerGradient = LinearGradient(
    colors: <Color>[
      homeBlueTop,
      homeBlueMid,
      backgroundCanvas,
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: <double>[0.0, 0.5, 1.0],
  );

  /// Home screen — soft blue wash (no gray cast).
  static const LinearGradient homeCanvasGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[
      homeBlueTop,
      homeBlueMid,
      homeBlueBottom,
    ],
    stops: <double>[0.0, 0.45, 1.0],
  );

  static List<BoxShadow> get cardShadow => <BoxShadow>[
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get shadowElevated => <BoxShadow>[
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get searchBarShadow => <BoxShadow>[
        BoxShadow(
          color: brandPrimary.withValues(alpha: 0.08),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ];

  static Color get glassFill => Colors.white.withValues(alpha: 0.72);
  static Color get glassBorder => Colors.white.withValues(alpha: 0.35);
}
