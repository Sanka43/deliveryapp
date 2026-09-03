import 'package:flutter/material.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/theme/app_text_styles.dart';

/// Light watermark when network images fail or are missing.
/// Display "MND" title + "Master N Delivery" subtitle, width-aligned.
class MndBrandWatermark extends StatelessWidget {
  const MndBrandWatermark({
    super.key,
    this.mndFontSize = 40,
    @Deprecated('Subtitle always uses theme labelSmall')
    this.subtitleFontSize,
    this.mndOpacity = 0.26,
    this.subtitleOpacity = 0.2,
  });

  /// Scalable Bebas Neue size for the "MND" watermark.
  final double mndFontSize;

  /// Ignored — kept for call-site compatibility.
  @Deprecated('Subtitle always uses theme labelSmall')
  final double? subtitleFontSize;
  final double mndOpacity;
  final double subtitleOpacity;

  @override
  Widget build(BuildContext context) {
    final TextDirection dir = Directionality.of(context);
    final Color accent = AppColors.brandPrimary;

    final TextStyle mndStyle = AppTextStyles.brandMark(
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

    final TextStyle subtitleStyle =
        (Theme.of(context).textTheme.labelSmall ?? const TextStyle()).copyWith(
      color: accent.withValues(alpha: subtitleOpacity),
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
      height: 1.1,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text('MND', style: mndStyle, textAlign: TextAlign.center),
        SizedBox(
          width: mndPainter.width,
          child: Text(
            'Master N Delivery',
            style: subtitleStyle,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
