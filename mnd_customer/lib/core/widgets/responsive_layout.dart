import 'package:flutter/material.dart';
import 'package:mnd_delivery_app/core/utils/responsive.dart';

class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    required this.mobile,
    required this.tablet,
    super.key,
  });

  final Widget mobile;
  final Widget tablet;

  @override
  Widget build(BuildContext context) {
    return Responsive.isTablet(context) ? tablet : mobile;
  }
}
