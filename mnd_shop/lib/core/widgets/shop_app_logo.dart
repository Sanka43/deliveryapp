import 'package:flutter/material.dart';

/// Branded MND Vendor logo used on auth screens (login, registration).
class ShopAppLogo extends StatelessWidget {
  const ShopAppLogo({
    super.key,
    this.width = 180,
    this.borderRadius = 16,
    this.boxShadow,
  });

  final double width;
  final double borderRadius;
  final List<BoxShadow>? boxShadow;

  static const String assetPath = 'assets/shop_auth_logo.png';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: boxShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        assetPath,
        width: width,
        fit: BoxFit.contain,
      ),
    );
  }
}
