/**
 * One-off backfill for the missing shop product cost on regular customer-app
 * COD orders (`placeCashOnDeliveryOrder`).
 *
 * Root cause: `productCashLkr` was only ever computed by `completeDeliveryOrder`
 * — but that function is exclusively for vendor-manual "actual trip" orders
 * (`deliveryFeeMode === 'actual_trip'`, see `placeVendorManualOrder`). Regular
 * catalog orders never got that field written anywhere: not at placement, and
 * not at delivery — the rider app's own delivery confirmation for these orders
 * (`updateOrderStatus` in rider_orders_repository.dart) just flips
 * `status: 'delivered'` directly in Firestore with no recalculation. Every
 * such order therefore undercharged the rider by the full shop product cost
 * (`subtotal - discount`), both on the order document and — for orders
 * already delivered — on the rider's `cash_ledger` entry and running
 * `cashOwedToAdminLkr` counter. `placeCashOnDeliveryOrder` now sets the field
 * at placement (see placeOrder.ts), so this script only matters for orders
 * that predate that fix.
 *
 * What this script does, per affected order:
 *
 *  1. Always backfills `productCashLkr` / `productCashStatus` on the order
 *     document itself, regardless of its status — this is a pure data-hygiene
 *     fix and is always correct for this order type (no `productsPaid`
 *     concept exists on `placeCashOnDeliveryOrder` orders; it's always full
 *     COD).
 *  2. If the order is `delivered` and its rider's cash_ledger entry
 *     (`order_{orderId}`) is still `open` (the rider hasn't requested a
 *     handover for it yet), also corrects the entry's `owedLkr` /
 *     `breakdown.productCashLkr` and bumps the rider's `cashOwedToAdminLkr`
 *     by the shortfall — this money hasn't changed hands yet, so raising what
 *     is still owed is safe and accurate. `cashInHandLkr` is untouched: it
 *     already reflects what the rider actually collected (`total`), which
 *     was never wrong.
 *
 * What it deliberately does NOT do:
 *
 *  - It does not touch entries already `pending_settlement` or `settled` —
 *    those have money already in flight or already closed based on the old,
 *    wrong figure. Retroactively asking a rider for a shortfall on money
 *    they already handed over is a policy call, not a script's to make.
 *    These are reported as `needsManualReview` instead.
 *  - It does not touch `deliveryFeeMode === 'actual_trip'` orders
 *    (vendor-manual) — those already compute `productCashLkr` correctly via
 *    `completeDeliveryOrder`, respecting that order type's own `productsPaid`
 *    flag.
 *
 * Idempotent by construction: an order already carrying `productCashLkr`
 * is skipped outright, and a ledger entry whose `breakdown.productCashLkr`
 * already matches the correct value contributes a zero shortfall. No marker
 * doc needed — safe to re-run.
 *
 * Usage (dry run prints a report and writes nothing):
 *
 *   cd functions && npm run build
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/sa.json node lib/scripts/backfillOrderProductCash.js
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/sa.json node lib/scripts/backfillOrderProductCash.js --apply
 *
 * Options:
 *   --apply           actually write (default is dry run)
 *   --order=<id>      backfill a single order, for a careful first pass
 *   --limit=<n>        stop after n affected orders
 *   --json=<path>      also write the full report as JSON
 */
import {writeFileSync} from "node:fs";
import {applicationDefault, initializeApp} from "firebase-admin/app";
import {FieldValue, getFirestore} from "firebase-admin/firestore";

type Args = {
  apply: boolean;
  orderId: string | null;
  limit: number;
  jsonPath: string | null;
};

export type OrderResult = {
  orderId: string;
  trackingNumber: string;
  status: string;
  subtotal: number;
  discount: number;
  correctProductCashLkr: number;
  orderDocPatched: boolean;
  ledgerAction:
    | "not-delivered"
    | "no-rider"
    | "already-paid-online"
    | "legacy-pre-cash-ledger"
    | "entry-missing-unexpected"
    | "entry-open-corrected"
    | "needs-manual-review";
  ledgerEntryStatus: string | null;
  shortfallAppliedLkr: number;
  riderId: string | null;
};

function parseArgs(argv: string[]): Args {
  const get = (prefix: string): string | null => {
    const hit = argv.find((a) => a.startsWith(prefix));
    return hit ? hit.slice(prefix.length) : null;
  };
  const limitRaw = Number(get("--limit=") ?? NaN);
  return {
    apply: argv.includes("--apply"),
    orderId: get("--order="),
    limit: Number.isFinite(limitRaw) && limitRaw > 0 ? limitRaw : Infinity,
    jsonPath: get("--json="),
  };
}

export function toWholeLkr(value: unknown): number {
  const n = Math.round(Number(value));
  return Number.isFinite(n) ? n : 0;
}

export function fmt(lkr: number): string {
  return `Rs. ${lkr.toLocaleString("en-LK")}`;
}

/**
 * Corrects one order: always patches the order doc, and — when safe — the
 * rider's open cash_ledger entry + running owed counter.
 */
export async function processOrder(args: {
  orderId: string;
  data: FirebaseFirestore.DocumentData;
  apply: boolean;
}): Promise<OrderResult> {
  const {orderId, data, apply} = args;
  const db = getFirestore();

  const subtotal = toWholeLkr(data.subtotal);
  const discount = toWholeLkr(data.discount);
  const correctProductCashLkr = Math.max(0, subtotal - discount);
  const status = String(data.status ?? "").trim().toLowerCase();
  const riderId =
    String(data.riderId ?? data.assignedRiderId ?? "").trim() || null;
  const paymentStatus = String(data.paymentStatus ?? "").trim().toLowerCase();

  const result: OrderResult = {
    orderId,
    trackingNumber: String(data.trackingNumber ?? orderId),
    status,
    subtotal,
    discount,
    correctProductCashLkr,
    orderDocPatched: false,
    ledgerAction: "not-delivered",
    ledgerEntryStatus: null,
    shortfallAppliedLkr: 0,
    riderId,
  };

  if (apply) {
    await db.collection("orders").doc(orderId).set(
      {
        productCashLkr: correctProductCashLkr,
        productCashStatus: "owed",
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
  }
  result.orderDocPatched = apply;

  if (status !== "delivered") {
    return result;
  }
  if (paymentStatus === "paid") {
    result.ledgerAction = "already-paid-online";
    return result;
  }
  if (!riderId) {
    result.ledgerAction = "no-rider";
    return result;
  }

  const riderRef = db.collection("riders").doc(riderId);
  const entryRef = riderRef.collection("cash_ledger").doc(`order_${orderId}`);
  const entrySnap = await entryRef.get();
  if (!entrySnap.exists) {
    // Before riderCash.ts landed, onOrderDeliveredCreditRider credited the
    // full deliveryFee straight to the wallet and never wrote a cash_ledger
    // entry at all — every order from that era has an earning_{orderId}
    // transaction lacking `collectedInCash`. That money was already resolved
    // (see reconcileRiderCashWallets.ts, which claws back any wallet
    // over-credit for those exact jobs); inventing a cash debt for it now
    // would double-charge the rider. Only flag it if it's NOT explainable
    // that way — an order this recent with no txn record at all is a real
    // gap worth investigating.
    const txnSnap = await riderRef
      .collection("transactions")
      .doc(`earning_${orderId}`)
      .get();
    const txnData = txnSnap.data();
    result.ledgerAction =
      txnSnap.exists && txnData?.collectedInCash === undefined ?
        "legacy-pre-cash-ledger" :
        "entry-missing-unexpected";
    return result;
  }

  const entry = entrySnap.data() ?? {};
  const entryStatus = String(entry.status ?? "").trim().toLowerCase();
  result.ledgerEntryStatus = entryStatus;

  if (entryStatus !== "open") {
    result.ledgerAction = "needs-manual-review";
    const breakdown = (entry.breakdown ?? {}) as Record<string, unknown>;
    result.shortfallAppliedLkr =
      correctProductCashLkr - toWholeLkr(breakdown.productCashLkr);
    return result;
  }

  if (!apply) {
    const breakdown = (entry.breakdown ?? {}) as Record<string, unknown>;
    const missing = correctProductCashLkr - toWholeLkr(breakdown.productCashLkr);
    result.ledgerAction = "entry-open-corrected";
    result.shortfallAppliedLkr = Math.max(0, missing);
    return result;
  }

  const applied = await db.runTransaction(async (tx) => {
    const freshEntry = await tx.get(entryRef);
    if (!freshEntry.exists) {
      return 0;
    }
    const fe = freshEntry.data() ?? {};
    const feStatus = String(fe.status ?? "").trim().toLowerCase();
    if (feStatus !== "open") {
      return 0;
    }
    const feBreakdown = (fe.breakdown ?? {}) as Record<string, unknown>;
    const missing = Math.max(
      0,
      correctProductCashLkr - toWholeLkr(feBreakdown.productCashLkr),
    );
    if (missing <= 0) {
      return 0;
    }
    const newOwed = toWholeLkr(fe.owedLkr) + missing;
    const newBreakdown = {
      productCashLkr: toWholeLkr(feBreakdown.productCashLkr) + missing,
      serviceChargeLkr: toWholeLkr(feBreakdown.serviceChargeLkr),
      rideCommissionLkr: toWholeLkr(feBreakdown.rideCommissionLkr),
    };
    tx.update(entryRef, {owedLkr: newOwed, breakdown: newBreakdown});
    tx.set(
      riderRef,
      {
        cashOwedToAdminLkr: FieldValue.increment(missing),
        cashUpdatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
    return missing;
  });

  result.ledgerAction = "entry-open-corrected";
  result.shortfallAppliedLkr = applied;
  return result;
}

/**
 * Scans candidate orders and corrects each one. Shared by the CLI entry
 * point below and the temporary admin-only HTTP wrapper
 * (backfillOrderProductCashHttp.ts) used when no local service-account
 * credentials are available to run this as a standalone script.
 */
export async function runBackfill(
  args: Args,
): Promise<{scanned: number; results: OrderResult[]}> {
  const db = getFirestore();

  const orderDocs = args.orderId ?
    [await db.collection("orders").doc(args.orderId).get()] :
    (
      await db
        .collection("orders")
        .where("paymentMethod", "==", "cashOnDelivery")
        .get()
    ).docs;

  const results: OrderResult[] = [];
  let scanned = 0;

  for (const doc of orderDocs) {
    if (!doc.exists || results.length >= args.limit) {
      continue;
    }
    const data = doc.data() ?? {};
    // Vendor-manual (actual-trip) orders already compute productCashLkr
    // correctly via completeDeliveryOrder, respecting their own productsPaid
    // flag — leave them alone.
    if (String(data.deliveryFeeMode ?? "").trim() === "actual_trip") {
      continue;
    }
    // Already has the field — either a post-fix order, or already backfilled
    // by a previous run of this script.
    if (data.productCashLkr !== undefined) {
      continue;
    }
    scanned += 1;
    const result = await processOrder({orderId: doc.id, data, apply: args.apply});
    if (result.correctProductCashLkr > 0) {
      results.push(result);
    }
  }

  results.sort((a, b) => b.correctProductCashLkr - a.correctProductCashLkr);
  return {scanned, results};
}

async function main(): Promise<void> {
  const args = parseArgs(process.argv.slice(2));
  initializeApp({credential: applicationDefault()});

  console.log(
    args.apply ?
      "APPLYING corrections — orders and cash ledgers will be written.\n" :
      "DRY RUN — nothing will be written. Re-run with --apply to commit.\n",
  );

  const {scanned, results} = await runBackfill(args);

  console.log(`Scanned ${scanned} affected order(s); ${results.length} had a real product cost.\n`);
  for (const r of results) {
    console.log(
      `${r.trackingNumber} (${r.orderId}) — status: ${r.status}\n` +
        `    subtotal - discount     : ${fmt(r.correctProductCashLkr)}\n` +
        `    order doc               : productCashLkr backfilled\n` +
        `    ledger action           : ${r.ledgerAction}` +
        (r.riderId ? ` (rider ${r.riderId})` : "") +
        "\n" +
        (r.ledgerAction === "entry-open-corrected" ?
          `    owed increased by       : ${fmt(r.shortfallAppliedLkr)}\n` :
          "") +
        (r.ledgerAction === "needs-manual-review" ?
          `    ALREADY ${r.ledgerEntryStatus?.toUpperCase()} for  : ${fmt(r.shortfallAppliedLkr)} too little — admin must decide whether to collect this separately\n` :
          ""),
    );
  }

  const corrected = results.filter((r) => r.ledgerAction === "entry-open-corrected");
  const manual = results.filter((r) => r.ledgerAction === "needs-manual-review");
  const legacy = results.filter((r) => r.ledgerAction === "legacy-pre-cash-ledger");
  const unexpected = results.filter((r) => r.ledgerAction === "entry-missing-unexpected");
  const totalCorrected = corrected.reduce((s, r) => s + r.shortfallAppliedLkr, 0);
  const totalManual = manual.reduce((s, r) => s + r.shortfallAppliedLkr, 0);
  console.log("—".repeat(60));
  console.log(`Order docs backfilled                    : ${results.length}`);
  console.log(`Open ledger entries corrected             : ${corrected.length} (${fmt(totalCorrected)})`);
  console.log(`Needs manual review (already settled)     : ${manual.length} (${fmt(totalManual)})`);
  console.log(`Pre-cash-ledger legacy orders (untouched)  : ${legacy.length}`);
  if (unexpected.length > 0) {
    console.log(`UNEXPECTED — no ledger entry, no legacy explanation: ${unexpected.length} — investigate individually`);
  }
  if (!args.apply) {
    console.log("\nNothing was written. Re-run with --apply to commit.");
  }

  if (args.jsonPath) {
    writeFileSync(
      args.jsonPath,
      JSON.stringify(
        {generatedAt: new Date().toISOString(), applied: args.apply, results},
        null,
        2,
      ),
    );
    console.log(`\nReport written to ${args.jsonPath}`);
  }
}

// Fail loudly: a half-finished money migration is worse than one that stopped.
// Guarded so importing runBackfill/processOrder elsewhere (the temporary
// admin HTTP wrapper) doesn't also run the CLI entry point as a side effect.
if (require.main === module) {
  main().catch((err) => {
    console.error("Backfill failed:", err);
    process.exitCode = 1;
  });
}
