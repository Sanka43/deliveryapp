import 'package:flutter/material.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';

/// Night navy auth backdrop shared by login + register.
class RiderAuthNightBackground extends StatelessWidget {
  const RiderAuthNightBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                AppColors.heroNavy,
                AppColors.heroNavyDeep,
                Color(0xFF081822),
                Color(0xFF050E16),
              ],
              stops: <double>[0.0, 0.32, 0.62, 1.0],
            ),
          ),
        ),
        Positioned(
          top: -size.height * 0.05,
          left: size.width * 0.1,
          right: size.width * 0.1,
          child: IgnorePointer(
            child: Container(
              height: size.height * 0.38,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 0.85,
                  colors: <Color>[
                    AppColors.brandSecondary.withValues(alpha: 0.22),
                    AppColors.primaryBlue.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                  stops: const <double>[0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: size.height * 0.55,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.transparent,
                    const Color(0xFF040A10).withValues(alpha: 0.55),
                    const Color(0xFF03070C).withValues(alpha: 0.92),
                  ],
                  stops: const <double>[0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: size.height * 0.28,
          left: -size.width * 0.35,
          child: IgnorePointer(
            child: Container(
              width: size.width * 0.75,
              height: size.width * 0.55,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[
                    AppColors.primaryBlue.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
