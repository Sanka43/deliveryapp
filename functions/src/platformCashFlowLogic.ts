import {dayKey} from "./vendorStatsLogic";

/** One day's worth of increments to apply to `platform_daily_cashflow/{docId}`. */
export type CashFlowMutation = {
  docId: string;
  increments: Record<string, number>;
};

function toDate(ts: unknown, fallback: Date): Date {
  if (
    ts != null &&
    typeof ts === "object" &&
    "toDate" in ts &&
    typeof (ts as {toDate: unknown}).toDate === "function"
  ) {
    const d = (ts as {toDate: () => Date}).toDate();
    if (d instanceof Date && !Number.isNaN(d.getTime())) {
      return d;
    }
  }
  return fallback;
}

export function readNumber(value: unknown): number {
  const n = Number(value ?? 0);
  return Number.isFinite(n) ? n : 0;
}

/**
 * Converts flat "category.leaf" keys (as produced by every mutation
 * function below, e.g. "income.orderCommissionLkr") into a properly
 * nested object: {income: {orderCommissionLkr: value}}.
 *
 * This matters because Firestore's `.set(data, {merge: true})` does NOT
 * interpret a dotted string key as a nested field path the way `.update()`
 * does — passed flat, "income.orderCommissionLkr" is stored as one literal
 * field NAMED "income.orderCommissionLkr", not as income.orderCommissionLkr
 * inside a nested income map. Both platformCashFlow.ts (live triggers) and
 * platformCashFlowBackfill.ts must run their increments through this
 * before writing, or the document shape silently doesn't match what
 * mnd_web/js/views/cashflow.js reads (doc.income.orderCommissionLkr).
 * Multiple keys under the same category merge into one nested object.
 */
export function nestDottedFields(
  fields: Record<string, unknown>,
): Record<string, unknown> {
  const result: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(fields)) {
    const dotIndex = key.indexOf(".");
    if (dotIndex === -1) {
      result[key] = value;
      continue;
    }
    const category = key.slice(0, dotIndex);
    const leaf = key.slice(dotIndex + 1);
    const bucket = (result[category] as Record<string, unknown> | undefined) ?? {};
    bucket[leaf] = value;
    result[category] = bucket;
  }
  return result;
}

function readStatus(value: unknown): string {
  return String(value ?? "").trim().toLowerCase();
}

function single(
  at: unknown,
  field: string,
  amount: number,
  fallbackDate: Date,
): CashFlowMutation[] {
  if (amount === 0) {
    return [];
  }
  return [{docId: dayKey(toDate(at, fallbackDate)), increments: {[field]: amount}}];
}

function isCompletedOrderStatus(status: string): boolean {
  return status === "completed" || status === "delivered";
}

/**
 * Referral rewards are implemented entirely as newly-minted single-use
 * coupons (functions/src/referrals.ts) rather than their own ledger:
 * `REF-{code}-{uid}` for the referee's signup discount,
 * `REFR-{orderId}` for the referrer's reward once that referee's first
 * order is delivered. Both prefixes start with "REF", which is what lets
 * this split their cost out from ordinary admin/vendor coupon discounts
 * without a separate data model.
 */
function isReferralCouponCode(couponCode: unknown): boolean {
  return String(couponCode ?? "").trim().toUpperCase().startsWith("REF");
}

export function discountCostField(order: Record<string, unknown>): string {
  return isReferralCouponCode(order.couponCode)
    ? "discountCost.referralsLkr"
    : "discountCost.couponsLkr";
}

/**
 * Order-level cash events — all three land on the same `orders/{orderId}`
 * document, so one trigger covers them instead of three separate ones:
 *  - Completion (status -> completed/delivered): platform income = the
 *    admin-set orderCommissionLkr + the IPG gateway fee it fronted at
 *    checkout; whatever coupon/referral discount applied on the order is
 *    tracked as a cost. Reversed (direction -1) if the order is later
 *    un-completed/cancelled after having been counted, mirroring
 *    vendorStatsLogic's isCompletedStatus symmetry so the aggregate can't
 *    drift from a status correction.
 *  - Refund (paymentStatus -> refunded): outgoing = the refunded amount
 *    (order.total — no separate refund-amount field exists; every refund
 *    call site in orderRefunds.ts uses the order's own total).
 *  - COD settlement (productCashStatus -> settled_to_shop): outgoing =
 *    productCashLkr, the cash a rider collected that the platform has now
 *    paid on to the shop.
 * Deliberately does NOT include orderRiderCommissionLkr (the platform's
 * cut of the delivery fee, credited in riderEarnings.ts) — that amount is
 * capped by the actual delivery fee inside a computation this module would
 * have to duplicate to get right, and getting it wrong would silently
 * misstate income. Left for a later pass once that logic is shared instead
 * of re-derived.
 */
export function mutationsForOrderUpdated(
  before: Record<string, unknown>,
  after: Record<string, unknown>,
  fallbackDate: Date,
): CashFlowMutation[] {
  const mutations: CashFlowMutation[] = [];
  const at = after.deliveredAt ?? after.completedAt ?? after.createdAt;

  const beforeCompleted = isCompletedOrderStatus(readStatus(before.status));
  const afterCompleted = isCompletedOrderStatus(readStatus(after.status));
  if (!beforeCompleted && afterCompleted) {
    mutations.push(
      ...single(at, "income.orderCommissionLkr", readNumber(after.orderCommissionLkr), fallbackDate),
      ...single(at, "income.ipgFeeLkr", readNumber(after.ipgFeeLkr), fallbackDate),
      ...single(at, discountCostField(after), readNumber(after.discount), fallbackDate),
    );
  } else if (beforeCompleted && !afterCompleted) {
    mutations.push(
      ...single(at, "income.orderCommissionLkr", -readNumber(before.orderCommissionLkr), fallbackDate),
      ...single(at, "income.ipgFeeLkr", -readNumber(before.ipgFeeLkr), fallbackDate),
      ...single(at, discountCostField(before), -readNumber(before.discount), fallbackDate),
    );
  }

  if (readStatus(before.paymentStatus) !== "refunded" && readStatus(after.paymentStatus) === "refunded") {
    mutations.push(
      ...single(after.refundedAt ?? at, "outgoing.refundsPaidLkr", readNumber(after.total), fallbackDate),
    );
  }

  if (
    readStatus(before.productCashStatus) !== "settled_to_shop" &&
    readStatus(after.productCashStatus) === "settled_to_shop"
  ) {
    mutations.push(
      ...single(
        after.productCashSettledAt ?? at,
        "outgoing.codSettledToShopLkr",
        readNumber(after.productCashLkr),
        fallbackDate,
      ),
    );
  }

  return mutations;
}

/**
 * Trip reaches completed+paid (same guard as onTripCompletedCreditRider):
 * platform income = the flat rideCommissionLkr rate in effect right now.
 * Rate isn't snapshotted per-trip, so a later rate change reclassifies
 * historical days the same way the existing dashboard estimate already
 * does — a known, pre-existing approximation, not new to this aggregate.
 */
export function mutationsForTripUpdated(
  before: Record<string, unknown>,
  after: Record<string, unknown>,
  rideCommissionLkr: number,
  fallbackDate: Date,
): CashFlowMutation[] {
  const afterReady = readStatus(after.status) === "completed" && readStatus(after.paymentStatus) === "paid";
  const beforeReady = readStatus(before.status) === "completed" && readStatus(before.paymentStatus) === "paid";
  if (!afterReady || beforeReady) {
    return [];
  }
  const fareLkr = readNumber(after.estimatedFareLkr);
  if (fareLkr <= 0) {
    return [];
  }
  const commissionLkr = Math.min(fareLkr, Math.max(0, rideCommissionLkr));
  return single(after.updatedAt ?? after.createdAt, "income.rideCommissionLkr", commissionLkr, fallbackDate);
}

/** Rider withdrawal settled paid (adminSettleRiderWithdrawal). */
export function mutationsForWithdrawalUpdated(
  before: Record<string, unknown>,
  after: Record<string, unknown>,
  fallbackDate: Date,
): CashFlowMutation[] {
  if (readStatus(before.status) === "paid" || readStatus(after.status) !== "paid") {
    return [];
  }
  return single(
    after.processedAt ?? after.createdAt,
    "outgoing.riderWithdrawalsPaidLkr",
    readNumber(after.amountLkr),
    fallbackDate,
  );
}

/** Vendor payout settled paid (adminSettleVendorPayout). */
export function mutationsForPayoutUpdated(
  before: Record<string, unknown>,
  after: Record<string, unknown>,
  fallbackDate: Date,
): CashFlowMutation[] {
  if (readStatus(before.status) === "paid" || readStatus(after.status) !== "paid") {
    return [];
  }
  return single(
    after.processedAt ?? after.createdAt,
    "outgoing.vendorPayoutsPaidLkr",
    readNumber(after.amountLkr),
    fallbackDate,
  );
}

/** Monthly vendor commission invoice marked paid (mnd_web Fees & commissions page). */
export function mutationsForMonthlyInvoiceUpdated(
  before: Record<string, unknown>,
  after: Record<string, unknown>,
  fallbackDate: Date,
): CashFlowMutation[] {
  if (readStatus(before.status) === "paid" || readStatus(after.status) !== "paid") {
    return [];
  }
  return single(after.paidAt, "income.monthlyInvoiceLkr", readNumber(after.feeLkr), fallbackDate);
}
