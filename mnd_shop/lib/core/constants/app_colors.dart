import 'package:flutter/material.dart';

/// Vendor shop app palette — vivid brand, crisp neutrals, saturated semantics.
class AppColors {
  AppColors._();

  // —— Brand ——
  /// Seeds Material [ColorScheme] and primary actions.
  static const Color primaryBlue = Color(0xFF5B4DFF);
  /// Hero cards, primary CTAs, filter accents.
  static const Color vendorHeroBlue = Color(0xFF5B4DFF);
  /// Hero gradient end / workflow tiles.
  static const Color vendorHeroViolet = Color(0xFF7B5CFF);
  static const Color heroShadow = Color(0xFF3D32B8);

  /// Workflow grid (Home) — derived from brand.
  static const Color workflowTile = Color(0xFF5B4DFF);
  static const Color workflowDeep = Color(0xFF4A3FE0);
  static const Color workflowMutedOnBlue = Color(0xFFD8D4FF);
  static const Color workflowDivider = Color(0xFF9B8CFF);

  // —— Semantic ——
  static const Color openGreen = Color(0xFF12D67A);
  static const Color pulseGreen = Color(0xFF3EE99A);
  static const Color pendingAmber = Color(0xFFFFB020);
  static const Color orderRejectRed = Color(0xFFFF4D6A);
  static const Color closedGrey = Color(0xFF8B96A8);

  /// "NEW" order badge background.
  static const Color badgeNew = Color(0xFFFFF4CC);

  // —— Surfaces & text ——
  static const Color canvas = Color(0xFFF6F7FC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFEDF0F8);
  static const Color textCharcoal = Color(0xFF0C1222);
  static const Color textMuted = Color(0xFF6B778C);
  static const Color borderLight = Color(0xFFE4E8F2);

  // —— Bottom nav pill ——
  static const Color navBarDark = Color(0xFF0E1018);
  static const Color navBarActiveChip = Color(0xFFFFFFFF);
  static const Color navBarActiveForeground = navBarDark;
  static const Color navBarInactiveIcon = Color(0xFF8A94A8);

  /// Stat / metric tile gradient (light mode).
  static List<Color> get statTileGradientLight => <Color>[
        surface,
        const Color(0xFFF3F1FF),
      ];

  /// Stat / metric tile gradient (dark mode).
  static List<Color> get statTileGradientDark => <Color>[
        const Color(0xFF1A1D2E),
        const Color(0xFF232838),
      ];

  /// Hero card fill — optional subtle gradient for future use.
  static const List<Color> heroGradient = <Color>[
    vendorHeroBlue,
    vendorHeroViolet,
  ];
}
