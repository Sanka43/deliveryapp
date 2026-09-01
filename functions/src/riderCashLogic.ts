/**
 * Pure rider cash-in-hand math. No firebase-admin import on purpose — the
 * callables and triggers in riderCash.ts / riderEarnings.ts wrap these in
 * Firestore transactions, mirroring the vendorStatsLogic.ts split.
 *
 * The model in one line: `wallet.balanceLkr` is what the *platform* owes the
 * rider, so a job whose money the rider physically pocketed never credits it.
 * Instead the collected cash lands in `cashInHandLkr`, and the slice that must
 * reach admin (shop product cash + ride commission) lands in
 * `cashOwedToAdminLkr`.
 */

/** Flat LKR the platform keeps per completed passenger ride. */
export const DEFAULT_RIDE_COMMISSION_LKR = 0;

/** Cash a rider may hold before new jobs stop being claimable. */
export const DEFAULT_MAX_CASH_IN_HAND_LKR = 7000;

/** Upper bound accepted from admin config, matching the fare-config caps. */
export const MAX_CONFIGURABLE_LKR = 1000000;

/**
 * Ledger entries a single settlement may cover.
 *
 * Confirming writes one update per entry, one per covered order, plus the
 * settlement, the rider doc, and a ledger row — so the worst case is
 * 2N + 3 writes against Firestore's 500-per-transaction limit. 200 keeps that
 * at 403 with room to spare; a rider carrying more than 200 unsettled jobs
 * simply hands over in two batches rather than hitting a failed confirm.
 */
export const MAX_SETTLEMENT_ENTRIES = 200;

export type RiderCashCounters = {
  cashInHandLkr: number;
  cashOwedToAdminLkr: number;
  cashPendingSettlementLkr: number;
};

export type CashEntryAmounts = {
  /** Cash the rider physically took from the customer. */
  cashLkr: number;
  /** Of that, what must reach admin. */
  owedLkr: number;
};

export type CashSettlementAction = "confirmed" | "rejected";

function toWholeLkr(value: unknown): number {
  const n = Math.round(Number(value));
  return Number.isFinite(n) ? n : 0;
}

function clampNonNegative(value: number): number {
  return value > 0 ? value : 0;
}

/**
 * Reads a whole-rupee config knob, falling back when it is missing, not a
 * number, negative, or implausibly large. Same guard shape as
 * loadPlatformFeeConfig's serviceChargePercent handling.
 */
export function readLkrConfig(raw: unknown, fallback: number): number {
  const n = Number(raw);
  if (!Number.isFinite(n) || n < 0 || n > MAX_CONFIGURABLE_LKR) {
    return fallback;
  }
  return Math.round(n);
}

/**
 * True once the rider is holding more cash than the configured ceiling.
 * Strictly greater than: a rider sitting exactly on the limit is still clear.
 */
export function evaluateCashHold(args: {
  cashInHandLkr: number;
  maxCashInHandLkr: number;
}): boolean {
  const cash = toWholeLkr(args.cashInHandLkr);
  const max = toWholeLkr(args.maxCashInHandLkr);
  if (max <= 0) {
    return false;
  }
  return cash > max;
}

/**
 * Cash the rider ends up holding after a passenger trip. `null` for trips
 * where the platform collected the money (PayHere) — those credit the wallet
 * instead.
 */
export function cashEntryForTrip(args: {
  fareLkr: unknown;
  commissionLkr: unknown;
  paymentMethod: unknown;
}): CashEntryAmounts | null {
  const method = String(args.paymentMethod ?? "").trim().toLowerCase();
  if (method !== "cash") {
    return null;
  }
  const cashLkr = clampNonNegative(toWholeLkr(args.fareLkr));
  if (cashLkr <= 0) {
    return null;
  }
  // Commission can never exceed the fare actually collected, otherwise a
  // misconfigured flat rate would invent debt on a cheap ride.
  const owedLkr = Math.min(cashLkr, clampNonNegative(toWholeLkr(args.commissionLkr)));
  return {cashLkr, owedLkr};
}

/**
 * Cash the rider ends up holding after a delivery. `null` when the customer
 * already paid online — nothing changed hands at the door.
 *
 * `amountDueFromCustomerLkr` is written by completeDeliveryOrder for
 * vendor-manual / actual-trip orders; plain COD orders don't have it, so the
 * order `total` is the honest fallback for what the rider collected.
 */
export function cashEntryForOrder(args: {
  amountDueFromCustomerLkr: unknown;
  totalLkr: unknown;
  productCashLkr: unknown;
  paymentStatus: unknown;
}): CashEntryAmounts | null {
  const paid = String(args.paymentStatus ?? "").trim().toLowerCase() === "paid";
  if (paid) {
    return null;
  }
  const due = Number(args.amountDueFromCustomerLkr);
  const collected = Number.isFinite(due) ?
    toWholeLkr(due) :
    toWholeLkr(args.totalLkr);
  const cashLkr = clampNonNegative(collected);
  if (cashLkr <= 0) {
    return null;
  }
  const owedLkr = Math.min(cashLkr, clampNonNegative(toWholeLkr(args.productCashLkr)));
  return {cashLkr, owedLkr};
}

/** Counters after a cash job is recorded, plus the resulting hold state. */
export function applyCashEntry(args: {
  counters: RiderCashCounters;
  entry: CashEntryAmounts;
  maxCashInHandLkr: number;
}): {counters: RiderCashCounters; holdActive: boolean} {
  const counters: RiderCashCounters = {
    cashInHandLkr: clampNonNegative(
      toWholeLkr(args.counters.cashInHandLkr) + args.entry.cashLkr,
    ),
    cashOwedToAdminLkr: clampNonNegative(
      toWholeLkr(args.counters.cashOwedToAdminLkr) + args.entry.owedLkr,
    ),
    cashPendingSettlementLkr: clampNonNegative(
      toWholeLkr(args.counters.cashPendingSettlementLkr),
    ),
  };
  return {
    counters,
    holdActive: evaluateCashHold({
      cashInHandLkr: counters.cashInHandLkr,
      maxCashInHandLkr: args.maxCashInHandLkr,
    }),
  };
}

/**
 * Settlement outcome math. Confirming clears the covered cash and the owed
 * slice; rejecting only releases the pending lock so the rider can try again.
 * Idempotent for a replayed terminal status, like applyWithdrawalSettlement.
 */
export function applyCashSettlement(args: {
  action: CashSettlementAction;
  status: string;
  amountLkr: number;
  cashCoveredLkr: number;
  counters: RiderCashCounters;
  maxCashInHandLkr: number;
}): {
  alreadyDone: boolean;
  nextStatus: CashSettlementAction;
  counters: RiderCashCounters;
  holdActive: boolean;
} {
  const status = String(args.status ?? "").trim().toLowerCase();
  const amount = toWholeLkr(args.amountLkr);
  const cashCovered = toWholeLkr(args.cashCoveredLkr);
  if (amount < 0 || cashCovered <= 0) {
    throw Object.assign(new Error("Invalid settlement amount."), {
      code: "invalid-argument",
    });
  }

  const current: RiderCashCounters = {
    cashInHandLkr: toWholeLkr(args.counters.cashInHandLkr),
    cashOwedToAdminLkr: toWholeLkr(args.counters.cashOwedToAdminLkr),
    cashPendingSettlementLkr: toWholeLkr(args.counters.cashPendingSettlementLkr),
  };
  const holdFor = (counters: RiderCashCounters): boolean =>
    evaluateCashHold({
      cashInHandLkr: counters.cashInHandLkr,
      maxCashInHandLkr: args.maxCashInHandLkr,
    });

  if (status === args.action) {
    return {
      alreadyDone: true,
      nextStatus: args.action,
      counters: current,
      holdActive: holdFor(current),
    };
  }
  if (status !== "requested") {
    throw Object.assign(
      new Error(`Cannot mark ${args.action} from "${status || "none"}".`),
      {code: "failed-precondition"},
    );
  }

  if (args.action === "rejected") {
    const counters: RiderCashCounters = {
      ...current,
      cashPendingSettlementLkr: 0,
    };
    return {
      alreadyDone: false,
      nextStatus: "rejected",
      counters,
      holdActive: holdFor(counters),
    };
  }

  const counters: RiderCashCounters = {
    cashInHandLkr: clampNonNegative(current.cashInHandLkr - cashCovered),
    cashOwedToAdminLkr: clampNonNegative(current.cashOwedToAdminLkr - amount),
    cashPendingSettlementLkr: 0,
  };
  return {
    alreadyDone: false,
    nextStatus: "confirmed",
    counters,
    holdActive: holdFor(counters),
  };
}
