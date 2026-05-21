import 'package:flutter/material.dart';
import 'package:mnd_shop/core/constants/app_colors.dart';

/// Product catalogue + add/edit form colors (aligned with [VendorOrdersTheme]).
abstract final class VendorProductsTheme {
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

  static Color accent(BuildContext context) =>
      isDark(context) ? const Color(0xFF8B7EFF) : AppColors.vendorHeroBlue;

  static Color cardSurface(BuildContext context) =>
      isDark(context) ? const Color(0xFF1A2030) : Colors.white;

  static Color statTileSurface(BuildContext context) =>
      isDark(context) ? const Color(0xFF1E2433) : Colors.white;

  static Color inputFill(BuildContext context) => isDark(context)
      ? Theme.of(context).colorScheme.surfaceContainerHigh
      : Colors.white;

  static Color inputBorder(BuildContext context) => isDark(context)
      ? Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.7)
      : AppColors.borderLight;

  static Color searchUnderline(BuildContext context) => isDark(context)
      ? Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.85)
      : AppColors.borderLight;

  static Color toggleTrack(BuildContext context) => isDark(context)
      ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.65)
      : AppColors.surfaceMuted.withValues(alpha: 0.85);

  static Color thumbPlaceholderFill(BuildContext context) => isDark(context)
      ? Theme.of(context).colorScheme.surfaceContainerHigh
      : AppColors.surfaceMuted;

  static Color softAccentFill(
    BuildContext context, {
    double lightAlpha = 0.1,
    double darkAlpha = 0.22,
  }) =>
      accent(context).withValues(alpha: isDark(context) ? darkAlpha : lightAlpha);

  static Color inventoryBannerFill(BuildContext context) =>
      AppColors.pendingAmber.withValues(alpha: isDark(context) ? 0.18 : 0.14);

  static Color chipSelectedFg(BuildContext context) =>
      isDark(context) ? AppColors.textCharcoal : Colors.white;

  static Color chipUnselectedFg(BuildContext context) => mutedText(context);

  static List<BoxShadow> cardShadow(BuildContext context) {
    if (!isDark(context)) {
      return <BoxShadow>[
        BoxShadow(
          color: AppColors.textCharcoal.withValues(alpha: 0.1),
          blurRadius: 14,
          offset: const Offset(0, 4),
          spreadRadius: -2,
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];
    }
    return <BoxShadow>[
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.5),
        blurRadius: 18,
        offset: const Offset(0, 6),
        spreadRadius: -4,
      ),
    ];
  }

  static Color productCardBackground(
    BuildContext context, {
    required bool isOut,
    required bool isLow,
  }) {
    final Color base = cardSurface(context);
    final bool dark = isDark(context);
    if (isOut) {
      return Color.lerp(base, AppColors.orderRejectRed, dark ? 0.3 : 0.14) ?? base;
    }
    if (isLow) {
      return Color.lerp(base, AppColors.pendingAmber, dark ? 0.28 : 0.16) ?? base;
    }
    return base;
  }

  static Color? productCardBorder(
    BuildContext context, {
    required bool isOut,
    required bool isLow,
  }) {
    final bool dark = isDark(context);
    if (isOut) {
      return AppColors.orderRejectRed.withValues(alpha: dark ? 0.45 : 0.22);
    }
    if (isLow) {
      return AppColors.pendingAmber.withValues(alpha: dark ? 0.42 : 0.24);
    }
    return null;
  }
}
