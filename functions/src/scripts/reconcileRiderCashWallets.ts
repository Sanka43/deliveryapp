/**
 * One-off reconciliation for wallet balances inflated before cash jobs stopped
 * crediting the wallet.
 *
 * Until riderCash.ts landed, `onTripCompletedCreditRider` credited the full
 * `estimatedFareLkr` and `onOrderDeliveredCreditRider` the full `deliveryFee`
 * to `riders/{id}/wallet/summary.balanceLkr` — even when the rider had already
 * been paid, in cash, at the kerb. Those riders can withdraw money the platform
 * never owed them. This script subtracts exactly those credits back out.
 *
 * What it deliberately does NOT do:
 *
 *  - It does not backfill `cash_ledger` for historical jobs. That cash was
 *    almost certainly settled offline; inventing the debt now would put most
 *    of your riders on hold for money they already handed over.
 *  - It does not retroactively apply `rideCommissionLkr`. Commission did not
 *    exist when those rides ran, so charging for it after the fact would take
 *    money from riders under a policy they never rode under.
 *
 * Both are one-line changes if you decide otherwise — see COMMISSION_FOR_PAST
 * below.
 *
 * Usage (dry run prints a report and writes nothing):
 *
 *   cd functions && npm run build
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/sa.json node lib/scripts/reconcileRiderCashWallets.js
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/sa.json node lib/scripts/reconcileRiderCashWallets.js --apply
 *
 * Options:
 *   --apply            actually write (default is dry run)
 *   --rider=<uid>      reconcile a single rider, for a careful first pass
 *   --limit=<n>        stop after n riders
 *   --json=<path>      also write the full report as JSON
 */
import {writeFileSync} from "node:fs";
import {applicationDefault, initializeApp} from "firebase-admin/app";
import {
  DocumentSnapshot,
  FieldValue,
  getFirestore,
} from "firebase-admin/firestore";
import {cashEntryForOrder, cashEntryForTrip} from "../riderCashLogic";

/**
 * Commission applied when re-deciding whether a historical ride was a cash
 * job. Zero on purpose: we only care *whether* cash changed hands, not how it
 * would be split under today's rates.
 */
const COMMISSION_FOR_PAST = 0;

/**
 * Marker id. A rider carrying this ledger row has already been reconciled, so
 * a second run is a no-op rather than a second deduction. Bump the suffix only
 * if you ever need to run a genuinely different correction.
 */
const MARKER_TXN_ID = "reconcile_cash_wallet_v1";

/** Firestore getAll fan-out per batch. */
const FETCH_CHUNK = 200;

type Args = {
  apply: boolean;
  riderId: string | null;
  limit: number;
  jsonPath: string | null;
};

type RiderResult = {
  riderId: string;
  riderName: string;
  overCreditLkr: number;
  cashJobs: number;
  balanceBeforeLkr: number;
  balanceAfterLkr: number;
  lifetimeEarnedBeforeLkr: number;
  lifetimeEarnedAfterLkr: number;
  /** Over-credit that could not be clawed back — already withdrawn. */
  shortfallLkr: number;
  skipped: "already-reconciled" | null;
};

function parseArgs(argv: string[]): Args {
  const get = (prefix: string): string | null => {
    const hit = argv.find((a) => a.startsWith(prefix));
    return hit ? hit.slice(prefix.length) : null;
  };
  const limitRaw = Number(get("--limit=") ?? NaN);
  return {
    apply: argv.includes("--apply"),
    riderId: get("--rider="),
    limit: Number.isFinite(limitRaw) && limitRaw > 0 ? limitRaw : Infinity,
    jsonPath: get("--json="),
  };
}

function toWholeLkr(value: unknown): number {
  const n = Math.round(Number(value));
  return Number.isFinite(n) ? n : 0;
}

function fmt(lkr: number): string {
  return `Rs. ${lkr.toLocaleString("en-LK")}`;
}

async function getAllChunked(
  refs: FirebaseFirestore.DocumentReference[],
): Promise<Map<string, DocumentSnapshot>> {
  const db = getFirestore();
  const out = new Map<string, DocumentSnapshot>();
  for (let i = 0; i < refs.length; i += FETCH_CHUNK) {
    const chunk = refs.slice(i, i + FETCH_CHUNK);
    const snaps = await db.getAll(...chunk);
    for (const snap of snaps) {
      out.set(snap.id, snap);
    }
  }
  return out;
}

/**
 * Total the rider was credited for jobs whose cash they physically collected.
 *
 * Only ledger rows written by the *old* code count. Every row the new triggers
 * write carries `collectedInCash` (true or false), so its presence is the
 * discriminator — rows that already follow the new rules were never credited
 * and must not be deducted again.
 */
async function overCreditForRider(riderId: string): Promise<{
  overCreditLkr: number;
  cashJobs: number;
}> {
  const db = getFirestore();
  const txnSnap = await db
    .collection("riders")
    .doc(riderId)
    .collection("transactions")
    .where("type", "in", ["ride_earning", "delivery_earning"])
    .get();

  const legacy = txnSnap.docs.filter(
    (d) => d.data().collectedInCash === undefined,
  );
  if (legacy.length === 0) {
    return {overCreditLkr: 0, cashJobs: 0};
  }

  const tripIds = new Set<string>();
  const orderIds = new Set<string>();
  for (const doc of legacy) {
    const d = doc.data();
    const tripId = String(d.tripId ?? "").trim();
    const orderId = String(d.orderId ?? "").trim();
    if (d.type === "ride_earning" && tripId) {
      tripIds.add(tripId);
    } else if (d.type === "delivery_earning" && orderId) {
      orderIds.add(orderId);
    }
  }

  const [trips, orders] = await Promise.all([
    getAllChunked([...tripIds].map((id) => db.collection("trips").doc(id))),
    getAllChunked([...orderIds].map((id) => db.collection("orders").doc(id))),
  ]);

  let overCreditLkr = 0;
  let cashJobs = 0;
  for (const doc of legacy) {
    const d = doc.data();
    const credited = toWholeLkr(d.amountLkr);
    if (credited <= 0) {
      continue;
    }

    let wasCashJob = false;
    if (d.type === "ride_earning") {
      const trip = trips.get(String(d.tripId ?? ""))?.data();
      if (trip) {
        wasCashJob =
          cashEntryForTrip({
            fareLkr: trip.estimatedFareLkr,
            commissionLkr: COMMISSION_FOR_PAST,
            paymentMethod: trip.paymentMethod,
          }) != null;
      }
    } else {
      const order = orders.get(String(d.orderId ?? ""))?.data();
      if (order) {
        wasCashJob =
          cashEntryForOrder({
            amountDueFromCustomerLkr: order.amountDueFromCustomer,
            totalLkr: order.total,
            productCashLkr: order.productCashLkr,
            serviceChargeLkr: order.serviceCharge,
            paymentStatus: order.paymentStatus,
          }) != null;
      }
    }

    if (wasCashJob) {
      overCreditLkr += credited;
      cashJobs += 1;
    }
  }

  return {overCreditLkr, cashJobs};
}

/**
 * Deducts the over-credit inside a transaction, clamped at zero, and leaves an
 * audit row behind. Returns what actually happened so the report can show both
 * the correction and any amount that was already withdrawn and is therefore
 * unrecoverable from the wallet.
 */
async function applyCorrection(args: {
  riderId: string;
  riderName: string;
  overCreditLkr: number;
  cashJobs: number;
  apply: boolean;
}): Promise<RiderResult> {
  const db = getFirestore();
  const riderRef = db.collection("riders").doc(args.riderId);
  const walletRef = riderRef.collection("wallet").doc("summary");
  const markerRef = riderRef.collection("transactions").doc(MARKER_TXN_ID);

  const [walletSnap, markerSnap] = await db.getAll(walletRef, markerRef);
  const w = walletSnap.data() ?? {};
  const balanceBefore = toWholeLkr(w.balanceLkr);
  const lifetimeBefore = toWholeLkr(w.lifetimeEarnedLkr);

  if (markerSnap.exists) {
    return {
      riderId: args.riderId,
      riderName: args.riderName,
      overCreditLkr: args.overCreditLkr,
      cashJobs: args.cashJobs,
      balanceBeforeLkr: balanceBefore,
      balanceAfterLkr: balanceBefore,
      lifetimeEarnedBeforeLkr: lifetimeBefore,
      lifetimeEarnedAfterLkr: lifetimeBefore,
      shortfallLkr: 0,
      skipped: "already-reconciled",
    };
  }

  const balanceAfter = Math.max(0, balanceBefore - args.overCreditLkr);
  const recovered = balanceBefore - balanceAfter;
  const shortfall = args.overCreditLkr - recovered;
  // lifetimeEarnedLkr now tracks platform-paid earnings only (the new triggers
  // increment it solely on the wallet-credit branch), so it moves with balance.
  const lifetimeAfter = Math.max(0, lifetimeBefore - args.overCreditLkr);

  const result: RiderResult = {
    riderId: args.riderId,
    riderName: args.riderName,
    overCreditLkr: args.overCreditLkr,
    cashJobs: args.cashJobs,
    balanceBeforeLkr: balanceBefore,
    balanceAfterLkr: balanceAfter,
    lifetimeEarnedBeforeLkr: lifetimeBefore,
    lifetimeEarnedAfterLkr: lifetimeAfter,
    shortfallLkr: shortfall,
    skipped: null,
  };

  if (!args.apply) {
    return result;
  }

  await db.runTransaction(async (tx) => {
    // Re-read inside the transaction: a payout could have landed since the
    // scan, and clamping against a stale balance could drive it negative.
    const [freshWallet, freshMarker] = await Promise.all([
      tx.get(walletRef),
      tx.get(markerRef),
    ]);
    if (freshMarker.exists) {
      return;
    }
    const fw = freshWallet.data() ?? {};
    const freshBalance = toWholeLkr(fw.balanceLkr);
    const freshLifetime = toWholeLkr(fw.lifetimeEarnedLkr);
    const freshAfter = Math.max(0, freshBalance - args.overCreditLkr);

    tx.set(
      walletRef,
      {
        balanceLkr: freshAfter,
        lifetimeEarnedLkr: Math.max(0, freshLifetime - args.overCreditLkr),
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
    tx.set(markerRef, {
      type: "wallet_reconciliation",
      status: "completed",
      amountLkr: -(freshBalance - freshAfter),
      title: "Cash-job wallet correction",
      subtitle: `${args.cashJobs} cash job(s) already paid at handover`,
      overCreditLkr: args.overCreditLkr,
      balanceBeforeLkr: freshBalance,
      balanceAfterLkr: freshAfter,
      shortfallLkr: args.overCreditLkr - (freshBalance - freshAfter),
      createdAt: FieldValue.serverTimestamp(),
    });
    tx.set(
      riderRef,
      {walletCashReconciledAt: FieldValue.serverTimestamp()},
      {merge: true},
    );
  });

  return result;
}

async function main(): Promise<void> {
  const args = parseArgs(process.argv.slice(2));
  initializeApp({credential: applicationDefault()});
  const db = getFirestore();

  console.log(
    args.apply ?
      "APPLYING corrections — wallets will be written.\n" :
      "DRY RUN — nothing will be written. Re-run with --apply to commit.\n",
  );

  const riderDocs = args.riderId ?
    [await db.collection("riders").doc(args.riderId).get()] :
    (await db.collection("riders").get()).docs;

  const results: RiderResult[] = [];
  let scanned = 0;

  for (const riderDoc of riderDocs) {
    if (!riderDoc.exists || results.length >= args.limit) {
      continue;
    }
    scanned += 1;
    const riderId = riderDoc.id;
    const riderName =
      String(riderDoc.data()?.fullName ?? "").trim() || riderId;

    const {overCreditLkr, cashJobs} = await overCreditForRider(riderId);
    if (overCreditLkr <= 0) {
      continue;
    }
    results.push(
      await applyCorrection({
        riderId,
        riderName,
        overCreditLkr,
        cashJobs,
        apply: args.apply,
      }),
    );
  }

  results.sort((a, b) => b.overCreditLkr - a.overCreditLkr);

  console.log(`Scanned ${scanned} rider(s); ${results.length} need correction.\n`);
  for (const r of results) {
    const note = r.skipped ? "  [already reconciled — skipped]" : "";
    console.log(
      `${r.riderName} (${r.riderId})${note}\n` +
        `    cash jobs credited in error : ${r.cashJobs}\n` +
        `    over-credit                 : ${fmt(r.overCreditLkr)}\n` +
        `    balance                     : ${fmt(r.balanceBeforeLkr)} -> ${fmt(r.balanceAfterLkr)}\n` +
        (r.shortfallLkr > 0 ?
          `    ALREADY WITHDRAWN           : ${fmt(r.shortfallLkr)} — recover outside the app\n` :
          ""),
    );
  }

  const totalOver = results.reduce((s, r) => s + r.overCreditLkr, 0);
  const totalShort = results.reduce((s, r) => s + r.shortfallLkr, 0);
  console.log("—".repeat(60));
  console.log(`Total over-credit found        : ${fmt(totalOver)}`);
  console.log(`Recoverable from wallets       : ${fmt(totalOver - totalShort)}`);
  console.log(`Already withdrawn (unrecovered): ${fmt(totalShort)}`);
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
main().catch((err) => {
  console.error("Reconciliation failed:", err);
  process.exitCode = 1;
});
