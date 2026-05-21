import 'package:flutter/material.dart';
import 'package:mnd_shop/core/constants/app_colors.dart';

/// Home dashboard colors — mirrors [VendorOrdersTheme] for consistency.
abstract final class VendorDashboardTheme {
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color canvas(BuildContext context) => isDark(context)
      ? Theme.of(context).colorScheme.surfaceContainerLowest
      : AppColors.canvas;

  static Color primaryText(BuildContext context) =>
      isDark(context) ? Theme.of(context).colorScheme.onSurface : AppColors.textCharcoal;

  static Color mutedText(BuildContext context) => isDark(context)
      ? Theme.of(context).colorScheme.onSurfaceVariant
      : AppColors.textMuted;

  static Color cardSurface(BuildContext context) =>
      isDark(context) ? const Color(0xFF1A2030) : Colors.white;

  static Color sectionBorder(BuildContext context) => isDark(context)
      ? Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.55)
      : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.28);

  static Color itemsBoxFill(BuildContext context) => isDark(context)
      ? Theme.of(context).colorScheme.surfaceContainerHigh
      : AppColors.surfaceMuted;

  static Color chartPriorLine(BuildContext context) => isDark(context)
      ? Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.75)
      : const Color(0xFFCBD5E1);

  static Color newBadgeBg(BuildContext context) =>
      isDark(context) ? Colors.white : AppColors.badgeNew;

  static Color newBadgeText(BuildContext context) =>
      isDark(context) ? AppColors.textCharcoal : AppColors.textCharcoal;

  static List<BoxShadow> elevatedCardShadow(BuildContext context) {
    if (!isDark(context)) {
      return <BoxShadow>[
        BoxShadow(
          color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.08),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
      ];
    }
    return <BoxShadow>[
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.45),
        blurRadius: 20,
        offset: const Offset(0, 8),
        spreadRadius: -4,
      ),
    ];
  }

  static List<BoxShadow> orderCardShadow(BuildContext context) {
    if (!isDark(context)) {
      return <BoxShadow>[
        BoxShadow(
          color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05),
          blurRadius: 36,
          spreadRadius: -8,
          offset: const Offset(0, 14),
        ),
        BoxShadow(
          color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.07),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ];
    }
    return <BoxShadow>[
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.4),
        blurRadius: 16,
        offset: const Offset(0, 6),
        spreadRadius: -2,
      ),
    ];
  }

  static List<Color> heroStatGradient(BuildContext context) =>
      isDark(context) ? AppColors.statTileGradientDark : AppColors.statTileGradientLight;

  static Color heroStatLabel(BuildContext context) => mutedText(context);

  static Color heroStatValue(BuildContext context) => primaryText(context);

  static Color heroStatBorder(BuildContext context) => isDark(context)
      ? Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.65)
      : AppColors.borderLight.withValues(alpha: 0.9);

  static Color heroShadowTint(BuildContext context) => isDark(context)
      ? Colors.black.withValues(alpha: 0.55)
      : AppColors.heroShadow.withValues(alpha: 0.55);
}
