import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mnd_delivery_app/core/constants/app_fonts.dart';

/// Brand / context-free text helpers. Prefer [ThemeData.textTheme] for UI text.
class AppTextStyles {
  AppTextStyles._();

  /// Bebas Neue "MND" brand mark — only exception to Plus Jakarta Sans UI text.
  static TextStyle brandMark({
    double fontSize = AppFonts.brandMark,
    Color? color,
    FontWeight fontWeight = FontWeight.w400,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.bebasNeue(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing ?? 1.2,
      height: height ?? 1.0,
    );
  }

  static TextStyle brandMarkCompact({
    Color? color,
    FontWeight fontWeight = FontWeight.w400,
  }) {
    return brandMark(
      fontSize: AppFonts.brandMarkCompact,
      color: color,
      fontWeight: fontWeight,
    );
  }
}
