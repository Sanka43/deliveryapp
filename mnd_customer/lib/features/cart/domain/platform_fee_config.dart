import 'package:mnd_delivery_app/features/cart/domain/delivery_pricing.dart';

/// Admin-tunable knobs mirrored from Firestore `platform_config/fees`
/// (edited on the "Fees & commissions" page in mnd_web). Mirrors the Cloud
/// Functions side (`functions/src/platformConfig.ts`) so the checkout
/// preview matches what the server actually charges.
class PlatformFeeConfig {
  const PlatformFeeConfig({
    required this.minimumFeeLkr,
    required this.perKmAfterIncludedLkr,
    required this.serviceChargePercent,
  });

  const PlatformFeeConfig.defaults()
      : minimumFeeLkr = DeliveryPricing.minimumFeeLkr,
        perKmAfterIncludedLkr = DeliveryPricing.perKmAfterIncludedLkr,
        serviceChargePercent = ServiceChargePricing.percent;

  final int minimumFeeLkr;
  final int perKmAfterIncludedLkr;
  final num serviceChargePercent;

  /// Builds from the `platform_config/fees` doc, falling back field-by-field
  /// to code defaults when the doc, or an individual field, is missing or
  /// out of range — mirrors `loadPlatformFeeConfig` in Cloud Functions.
  factory PlatformFeeConfig.fromFirestore(Map<String, dynamic>? data) {
    if (data == null) {
      return const PlatformFeeConfig.defaults();
    }
    final num? minFee = data['minDeliveryFeeLkr'] as num?;
    final num? perKm = data['pricePerKmLkr'] as num?;
    final num? pct = data['serviceChargePercent'] as num?;
    return PlatformFeeConfig(
      minimumFeeLkr: (minFee != null && minFee > 0)
          ? minFee.round()
          : DeliveryPricing.minimumFeeLkr,
      perKmAfterIncludedLkr: (perKm != null && perKm > 0)
          ? perKm.round()
          : DeliveryPricing.perKmAfterIncludedLkr,
      serviceChargePercent: (pct != null && pct >= 0 && pct <= 100)
          ? pct
          : ServiceChargePricing.percent,
    );
  }

  /// e.g. "5" for a whole percent, "5.5" for a fractional one.
  String get serviceChargePercentLabel => serviceChargePercent % 1 == 0
      ? serviceChargePercent.toStringAsFixed(0)
      : serviceChargePercent.toStringAsFixed(1);
}
