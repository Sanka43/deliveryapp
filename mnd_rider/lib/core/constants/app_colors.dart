import 'package:flutter/material.dart';

/// Brand, semantic, and surface tokens for MND Rider.
///
/// Prefer [ThemeData.colorScheme] / [TextTheme] in widgets. Use these constants
/// for brand/semantic accents and for building [AppTheme] schemes.
class AppColors {
  AppColors._();

  // Brand (aligned with customer #0B6EFF / rides accent)
  static const Color primaryBlue = Color(0xFF0B6EFF);
  static const Color primaryBlueDark = Color(0xFF0047B3);
  static const Color accentBlue = Color(0xFF1E6BFF);
  static const Color brandSecondary = Color(0xFF00C2FF);

  /// Auth / hero night panel (match customer login).
  static const Color heroNavy = Color(0xFF0B2F8A);
  static const Color heroNavyDeep = Color(0xFF071E5C);
  static const Color authMist = Color(0xFFE8F0FE);
  static const Color authInkLift = Color(0xFF0B1220);

  // Semantics
  static const Color onlineGreen = Color(0xFF16A34A);
  static const Color offlineGrey = Color(0xFF64748B);
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color errorRed = Color(0xFFDC2626);

  // Light surfaces (cool slate — clearer hierarchy vs pure gray)
  static const Color canvas = Color(0xFFF3F5F8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFEEF2F7);
  static const Color textCharcoal = Color(0xFF0B1220);
  static const Color textMuted = Color(0xFF5B6578);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color primaryContainerLight = Color(0xFFDBEAFE);
  static const Color onPrimaryContainerLight = Color(0xFF1E3A8A);

  // Dark surfaces (deep blue-ink — not pure black)
  static const Color darkCanvas = Color(0xFF0A0C14);
  static const Color darkSurface = Color(0xFF151A27);
  static const Color darkSurfaceLow = Color(0xFF10141F);
  static const Color darkSurfaceMid = Color(0xFF1A2030);
  static const Color darkSurfaceHigh = Color(0xFF222A3C);
  static const Color darkOnSurface = Color(0xFFF1F4FA);
  static const Color darkOnSurfaceVariant = Color(0xFF9AA3B8);
  static const Color darkOutline = Color(0xFF3A4356);
  static const Color darkOutlineVariant = Color(0xFF2C3445);
  static const Color darkPrimary = Color(0xFF6BABFF);
  static const Color darkOnPrimary = Color(0xFF06101F);
  static const Color darkPrimaryContainer = Color(0xFF1A3358);
  static const Color darkOnPrimaryContainer = Color(0xFFD6E8FF);
  static const Color darkError = Color(0xFFFF7A87);

  // Operational / map chrome (rides navy sheets)
  static const Color sheetNavy = Color(0xFF0B1F4A);
  static const Color sheetNavyDeep = Color(0xFF071533);
  static const Color mutedOnNavy = Color(0xFF9BB0D4);
  static const Color pickupGreen = Color(0xFF1B8A3E);
  static const Color dropoffRed = Color(0xFFE03B2F);
}
