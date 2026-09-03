import 'package:flutter/material.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';

/// Navy rides UI tokens (web-beta sheets — not food light palette).
class RidesColors {
  RidesColors._();

  static const int sheetNavy = 0xFF0B1F4A;
  static const int sheetNavyDeep = 0xFF071533;

  /// Mirrors [AppColors.brandPrimary] so the ride accent stays one source
  /// of truth instead of a second hardcoded brand-blue hex.
  static const Color accentBlue = AppColors.brandPrimary;
  static const int pickupGreen = 0xFF1B8A3E;
  static const int dropoffRed = 0xFFE03B2F;
  static const int stopAmber = 0xFFC77800;
  static const int cardWhite = 0xFFFFFFFF;
  static const int mutedOnNavy = 0xFF9BB0D4;
}

/// Shared chrome for floating navy cards over the map (booking / confirm / searching).
class RidesSheet {
  RidesSheet._();

  /// Left / right / bottom gutter so the map stays visible beside cards.
  static const double outerMargin = 12;

  /// Full corner radius for floating cards (not top-only sheets).
  static const double cardRadius = 16;

  /// Gap between floating card and CTA below.
  static const double cardGap = 10;

  /// Inner horizontal padding inside navy cards.
  static const double cardPaddingH = 16;

  /// Inner vertical padding inside navy cards.
  static const double cardPaddingTop = 18;
  static const double cardPaddingBottom = 14;

  static const double primaryButtonHeight = 54;
  static const double buttonRadius = 10;
  static const double actionIconSize = 20;
}
