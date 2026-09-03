import 'package:flutter/material.dart';
import 'package:mnd_delivery_app/features/rides/domain/ride_constants.dart';
import 'package:mnd_delivery_app/features/rides/presentation/rides_theme.dart';

/// Asset silhouettes for Wheel / Bike / Car (tintable black PNGs).
class RidesVehicleIcon extends StatelessWidget {
  const RidesVehicleIcon({
    super.key,
    required this.type,
    this.size = 44,
    this.color = RidesColors.accentBlue,
  });

  final RideVehicleType type;
  final double size;
  final Color color;

  static String assetFor(RideVehicleType type) {
    return switch (type) {
      RideVehicleType.wheel => 'assets/images/rides/vehicle_wheel.png',
      RideVehicleType.bike => 'assets/images/rides/vehicle_bike.png',
      RideVehicleType.car => 'assets/images/rides/vehicle_car.png',
    };
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        assetFor(type),
        width: size,
        height: size,
        fit: BoxFit.contain,
        color: color,
        colorBlendMode: BlendMode.srcIn,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => Icon(
          Icons.directions_car_rounded,
          size: size * 0.85,
          color: color,
        ),
      ),
    );
  }
}
