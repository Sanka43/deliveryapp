import 'package:flutter/material.dart';

/// Soft photo wash + light overlay — same chrome as rider login.
class RiderAuthLightBackground extends StatelessWidget {
  const RiderAuthLightBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Image.asset(
          'assets/images/onboarding/deliver.jpg',
          fit: BoxFit.cover,
          alignment: Alignment.center,
          errorBuilder: (
            BuildContext context,
            Object error,
            StackTrace? stackTrace,
          ) {
            return const ColoredBox(color: Color(0xFFF5F5F5));
          },
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Color(0xB3F5F5F5),
                Color(0xE6F5F5F5),
                Color(0xF5F5F5F5),
              ],
              stops: <double>[0.0, 0.45, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}
