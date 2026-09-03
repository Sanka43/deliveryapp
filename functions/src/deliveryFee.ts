/** Shared food/shop delivery fee curve (LKR). */

export const FALLBACK_FLAT_FEE_LKR = 180;
export const INCLUDED_KM = 1.5;
export const MINIMUM_FEE_LKR = 120;
export const PER_KM_AFTER_INCLUDED_LKR = 42;
export const MAX_FEE_LKR = 850;
export const EARTH_RADIUS_KM = 6371.0088;

export function haversineKm(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number,
): number {
  const toRad = (d: number) => (d * Math.PI) / 180;
  const phi1 = toRad(lat1);
  const phi2 = toRad(lat2);
  const dPhi = toRad(lat2 - lat1);
  const dLambda = toRad(lng2 - lng1);
  const a =
    Math.sin(dPhi / 2) ** 2 +
    Math.cos(phi1) * Math.cos(phi2) * Math.sin(dLambda / 2) ** 2;
  return EARTH_RADIUS_KM * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

/** Admin-tunable knobs for the curve above (see `platform_config/fees`). */
export type DeliveryFeeConfig = {
  minimumFeeLkr: number;
  perKmAfterIncludedLkr: number;
  includedKm: number;
  maxFeeLkr: number;
  flatFallbackLkr: number;
};

export const DEFAULT_DELIVERY_FEE_CONFIG: DeliveryFeeConfig = {
  minimumFeeLkr: MINIMUM_FEE_LKR,
  perKmAfterIncludedLkr: PER_KM_AFTER_INCLUDED_LKR,
  includedKm: INCLUDED_KM,
  maxFeeLkr: MAX_FEE_LKR,
  flatFallbackLkr: FALLBACK_FLAT_FEE_LKR,
};

/**
 * Store→dropoff estimate: ≤includedKm → minimumFeeLkr; else minimumFeeLkr +
 * ceil((km−includedKm)×perKmAfterIncludedLkr), cap maxFeeLkr.
 * Invalid / negative distance → flatFallbackLkr.
 */
export function feeLkrForDistanceKm(
  distanceKm: number,
  config: DeliveryFeeConfig = DEFAULT_DELIVERY_FEE_CONFIG,
): number {
  if (!Number.isFinite(distanceKm) || distanceKm < 0) {
    return config.flatFallbackLkr;
  }
  if (distanceKm <= config.includedKm) {
    return config.minimumFeeLkr;
  }
  const fee =
    config.minimumFeeLkr +
    Math.ceil((distanceKm - config.includedKm) * config.perKmAfterIncludedLkr);
  return Math.min(config.maxFeeLkr, fee);
}

/**
 * Actual rider path fee. Zero / missing km uses flat fallback (no GPS samples).
 */
export function feeLkrForActualTripKm(
  distanceKm: number,
  config: DeliveryFeeConfig = DEFAULT_DELIVERY_FEE_CONFIG,
): number {
  if (!Number.isFinite(distanceKm) || distanceKm <= 0) {
    return config.flatFallbackLkr;
  }
  return feeLkrForDistanceKm(distanceKm, config);
}

/** Round path km to 1 decimal for storage / display. */
export function roundTraveledKm(distanceKm: number): number {
  if (!Number.isFinite(distanceKm) || distanceKm < 0) {
    return 0;
  }
  return Math.round(distanceKm * 10) / 10;
}

/**
 * A rider-reported trip km can't be trusted on its own (no GPS trail is
 * stored) — but pickup→dropoff straight-line distance gives a cheap,
 * server-known bound to catch gross over/under-reporting. Real road
 * distance is essentially never below the straight line, and detours
 * (one-ways, river crossings) rarely exceed a few times it.
 */
export const MIN_PLAUSIBLE_RATIO = 0.5;
export const MAX_PLAUSIBLE_RATIO = 3.5;
export const MAX_PLAUSIBLE_BUFFER_KM = 3;

export function plausibleTripKmBounds(
  straightKm: number,
): {min: number; max: number} {
  if (!Number.isFinite(straightKm) || straightKm <= 0) {
    return {min: 0, max: Number.POSITIVE_INFINITY};
  }
  return {
    min: straightKm * MIN_PLAUSIBLE_RATIO,
    max: straightKm * MAX_PLAUSIBLE_RATIO + MAX_PLAUSIBLE_BUFFER_KM,
  };
}

/**
 * Clamps a rider-reported km to the plausible range for a known
 * pickup→dropoff straight-line distance. Returns the (possibly adjusted)
 * km plus whether it had to be adjusted, so the caller can flag the order
 * for admin review instead of silently trusting an outlier.
 */
export function clampTraveledKmToPlausibleRange(
  traveledKm: number,
  straightKm: number,
): {km: number; flagged: boolean} {
  const {min, max} = plausibleTripKmBounds(straightKm);
  if (traveledKm < min) {
    return {km: roundTraveledKm(min), flagged: true};
  }
  if (traveledKm > max) {
    return {km: roundTraveledKm(max), flagged: true};
  }
  return {km: traveledKm, flagged: false};
}
