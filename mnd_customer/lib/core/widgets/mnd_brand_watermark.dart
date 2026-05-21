import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';

/// Light watermark when network images fail or are missing.
/// Display "MND" title + "Master N Delivery" subtitle, width-aligned.
class MndBrandWatermark extends StatelessWidget {
  const MndBrandWatermark({
    super.key,
    this.mndFontSize = 40,
    this.subtitleFontSize = 12,
    this.mndOpacity = 0.26,
    this.subtitleOpacity = 0.2,
  });

  final double mndFontSize;
  final double subtitleFontSize;
  final double mndOpacity;
  final double subtitleOpacity;

  @override
  Widget build(BuildContext context) {
    final TextDirection dir = Directionality.of(context);
    final Color accent = AppColors.brandPrimary;

    final TextStyle mndStyle = GoogleFonts.bebasNeue(
      fontSize: mndFontSize,
      color: accent.withValues(alpha: mndOpacity),
      letterSpacing: 2.4,
      height: 0.9,
    );

    final TextPainter mndPainter = TextPainter(
      text: TextSpan(text: 'MND', style: mndStyle),
      textDirection: dir,
      maxLines: 1,
    )..layout();

    final double mndWidth = mndPainter.size.width;
    final double gap = (mndFontSize * 0.08).clamp(3.0, 6.0);

    final TextStyle subStyle = GoogleFonts.plusJakartaSans(
      fontSize: subtitleFontSize,
      fontWeight: FontWeight.w600,
      color: accent.withValues(alpha: subtitleOpacity),
      letterSpacing: 0.35,
      height: 1.2,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Text('MND', style: mndStyle),
        SizedBox(height: gap),
        Container(
          width: mndWidth * 0.5,
          height: 1.5,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(1),
            color: accent.withValues(alpha: mndOpacity * 0.55),
          ),
        ),
        SizedBox(height: gap * 0.65),
        SizedBox(
          width: mndWidth,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Text(
              'Master N Delivery',
              textAlign: TextAlign.center,
              maxLines: 2,
              style: subStyle,
            ),
          ),
        ),
      ],
    );
  }
}
