import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';

/// Home canvas — clean blue gradient with soft blue glow accents only.
class HomePageBackground extends StatelessWidget {
  const HomePageBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(gradient: AppColors.homeCanvasGradient),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _HomeOrb(
            top: -70,
            right: -50,
            size: 200,
            color: AppColors.brandPrimaryLight,
            opacity: 0.22,
          ),
          _HomeOrb(
            top: 180,
            left: -80,
            size: 190,
            color: AppColors.brandSecondary,
            opacity: 0.16,
          ),
          _HomeOrb(
            bottom: 80,
            right: -30,
            size: 170,
            color: AppColors.brandPrimary,
            opacity: 0.1,
          ),
        ],
      ),
    );
  }
}

class _HomeOrb extends StatelessWidget {
  const _HomeOrb({
    required this.size,
    required this.color,
    required this.opacity,
    this.top,
    this.left,
    this.right,
    this.bottom,
  });

  final double? top;
  final double? left;
  final double? right;
  final double? bottom;
  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: opacity),
          ),
        ),
      ),
    );
  }
}
