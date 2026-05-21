import 'package:flutter/material.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';

/// Branded gradient background for auth flows.
class RiderAuthGradientScaffold extends StatelessWidget {
  const RiderAuthGradientScaffold({
    super.key,
    required this.child,
    this.appBar,
  });

  final Widget child;
  final PreferredSizeWidget? appBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFF1E3A8A),
              AppColors.primaryBlue,
              Color(0xFF3B82F6),
            ],
          ),
        ),
        child: SafeArea(child: child),
      ),
    );
  }
}
