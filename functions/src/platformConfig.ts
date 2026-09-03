import {getFirestore} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {DEFAULT_DELIVERY_FEE_CONFIG, DeliveryFeeConfig} from "./deliveryFee";
import {
  DEFAULT_MAX_CASH_IN_HAND_LKR,
  DEFAULT_ORDER_RIDER_COMMISSION_LKR,
  DEFAULT_RIDE_COMMISSION_LKR,
  readLkrConfig,
} from "./riderCashLogic";
import {SERVICE_CHARGE_PERCENT} from "./serviceCharge";

/**
 * Admin-editable knobs from the "Fees & commissions" page in mnd_web
 * (`platform_config/fees`): `minDeliveryFeeLkr` / `pricePerKmLkr` feed the
 * delivery-fee curve, `serviceChargePercent` is the "Order commission" field
 * (which is the platform service charge shown to customers, not a separate
 * per-order commission), `rideCommissionLkr` is the flat cut the platform
 * keeps per completed passenger ride, `orderRiderCommissionLkr` is the flat
 * cut the platform keeps out of the delivery fee per delivered food order,
 * and `maxRiderCashInHandLkr` is how much cash a rider may hold before new
 * jobs stop being claimable.
 * includedKm / maxFee / flatFallback aren't exposed
 * there and stay fixed at their code defaults. Missing doc, missing fields,
 * or a read error all fall back to the hardcoded defaults so checkout never
 * breaks on a config problem.
 */
export type PlatformFeeConfig = {
  delivery: DeliveryFeeConfig;
  serviceChargePercent: number;
  rideCommissionLkr: number;
  orderRiderCommissionLkr: number;
  maxRiderCashInHandLkr: number;
};

const DEFAULT_PLATFORM_FEE_CONFIG: PlatformFeeConfig = {
  delivery: DEFAULT_DELIVERY_FEE_CONFIG,
  serviceChargePercent: SERVICE_CHARGE_PERCENT,
  rideCommissionLkr: DEFAULT_RIDE_COMMISSION_LKR,
  orderRiderCommissionLkr: DEFAULT_ORDER_RIDER_COMMISSION_LKR,
  maxRiderCashInHandLkr: DEFAULT_MAX_CASH_IN_HAND_LKR,
};

export async function loadPlatformFeeConfig(): Promise<PlatformFeeConfig> {
  try {
    const snap = await getFirestore()
      .collection("platform_config")
      .doc("fees")
      .get();
    if (!snap.exists) {
      return DEFAULT_PLATFORM_FEE_CONFIG;
    }
    const d = snap.data() ?? {};
    const minimumFeeLkr = Number(d.minDeliveryFeeLkr);
    const perKmAfterIncludedLkr = Number(d.pricePerKmLkr);
    const serviceChargePercent = Number(d.serviceChargePercent);
    return {
      delivery: {
        ...DEFAULT_DELIVERY_FEE_CONFIG,
        minimumFeeLkr:
          Number.isFinite(minimumFeeLkr) && minimumFeeLkr > 0
            ? minimumFeeLkr
            : DEFAULT_DELIVERY_FEE_CONFIG.minimumFeeLkr,
        perKmAfterIncludedLkr:
          Number.isFinite(perKmAfterIncludedLkr) && perKmAfterIncludedLkr > 0
            ? perKmAfterIncludedLkr
            : DEFAULT_DELIVERY_FEE_CONFIG.perKmAfterIncludedLkr,
      },
      serviceChargePercent:
        Number.isFinite(serviceChargePercent) &&
        serviceChargePercent >= 0 &&
        serviceChargePercent <= 100
          ? serviceChargePercent
          : SERVICE_CHARGE_PERCENT,
      rideCommissionLkr: readLkrConfig(
        d.rideCommissionLkr,
        DEFAULT_RIDE_COMMISSION_LKR,
      ),
      orderRiderCommissionLkr: readLkrConfig(
        d.orderRiderCommissionLkr,
        DEFAULT_ORDER_RIDER_COMMISSION_LKR,
      ),
      maxRiderCashInHandLkr: readLkrConfig(
        d.maxRiderCashInHandLkr,
        DEFAULT_MAX_CASH_IN_HAND_LKR,
      ),
    };
  } catch (err) {
    logger.warn("loadPlatformFeeConfig failed, using defaults", err);
    return DEFAULT_PLATFORM_FEE_CONFIG;
  }
}
