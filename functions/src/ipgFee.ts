/**
 * IPG (payment gateway) processing fee — added to the order total only when
 * paying online via PayHere, since PayHere charges MND a percentage of every
 * card transaction and that cost is passed on to the customer. Never applied
 * to Cash on Delivery orders.
 */

export const IPG_FEE_PERCENT = 3.3;

/** Rounds down, matching the percent-discount convention in coupons.ts. */
export function computeIpgFeeLkr(
  amountLkr: number,
  percent: number = IPG_FEE_PERCENT,
): number {
  if (!Number.isFinite(amountLkr) || amountLkr <= 0) {
    return 0;
  }
  return Math.floor((amountLkr * percent) / 100);
}
