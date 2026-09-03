/** Platform service charge: a flat percentage of order subtotal. */

export const SERVICE_CHARGE_PERCENT = 5;

/** Rounds down, matching the percent-discount convention in coupons.ts. */
export function computeServiceChargeLkr(
  subtotalLkr: number,
  percent: number = SERVICE_CHARGE_PERCENT,
): number {
  if (!Number.isFinite(subtotalLkr) || subtotalLkr <= 0) {
    return 0;
  }
  return Math.floor((subtotalLkr * percent) / 100);
}
