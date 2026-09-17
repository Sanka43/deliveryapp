import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {assertAdmin} from "./adminAuth";
import {readNumber} from "./platformCashFlowLogic";
import {loadPlatformFeeConfig} from "./platformConfig";
import {dayKey} from "./vendorStatsLogic";

const REGION = "asia-south1";
const BATCH_SIZE = 400; // Firestore hard caps a batch at 500 writes.

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

function add(
  totals: Map<string, Record<string, number>>,
  docId: string,
  field: string,
  amount: number,
): void {
  if (!amount) {
    return;
  }
  const bucket = totals.get(docId) ?? {};
  bucket[field] = (bucket[field] ?? 0) + amount;
  totals.set(docId, bucket);
}

/**
 * One-time admin operation that seeds platform_daily_cashflow with every
 * currently-settled money event that predates the live triggers in
 * platformCashFlow.ts (deployed alongside this), so the Cash Flow tab's
 * chart isn't empty for all of history on day one.
 *
 * Must run only once, and — critically — only ONCE per environment before
 * meaningful drift accumulates: it uses FieldValue.increment() the same
 * way the live triggers do, so re-running it would double-count everything
 * it already counted. Guarded by a marker doc; pass {force: true} to
 * re-run anyway (e.g. if a first attempt partially failed).
 *
 * Deliberately reuses only single-field-equality queries (no orderBy) so
 * it needs no new composite indexes — this runs once, so extra reads are
 * an acceptable trade for not blocking on an index build. Same event set
 * as platformCashFlowLogic.ts; see that file for what's covered and why
 * orderRiderCommissionLkr is excluded.
 */
export const backfillPlatformCashFlow = onCall(
  {region: REGION, timeoutSeconds: 540, memory: "512MiB"},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in as admin.");
    }
    await assertAdmin(request.auth.uid);
    const force = request.data?.force === true;

    const db = getFirestore();
    const markerRef = db.collection("platform_daily_cashflow_meta").doc("backfill");
    const markerSnap = await markerRef.get();
    if (markerSnap.exists && !force) {
      throw new HttpsError(
        "failed-precondition",
        "Backfill already ran. Pass force:true to re-run (this will double-count unless the collection was cleared first).",
      );
    }

    const totals = new Map<string, Record<string, number>>();
    const now = new Date();
    const failedSteps: Record<string, string> = {};
    const scannedCounts: Record<string, number> = {};

    // Each step is isolated: one query failing (e.g. a collection-group
    // index that's still building) must not discard every other step's
    // already-fetched, already-accumulated data — a single try/catch
    // around the whole function would do exactly that, since nothing gets
    // written until the very end. Failed steps are reported back so
    // they're easy to identify and re-run (this function is safe to call
    // again; FieldValue.increment only double-counts steps that actually
    // wrote, and a failed step never wrote anything).
    async function step(name: string, run: () => Promise<number>): Promise<void> {
      try {
        scannedCounts[name] = await run();
      } catch (e) {
        failedSteps[name] = e instanceof Error ? e.message : String(e);
        logger.warn(`backfillPlatformCashFlow step failed: ${name}`, {error: failedSteps[name]});
      }
    }

    await step("completedOrders", async () => {
      const snap = await db
        .collection("orders")
        .where("status", "in", ["completed", "delivered"])
        .get();
      for (const doc of snap.docs) {
        const o = doc.data();
        const at = o.deliveredAt ?? o.completedAt ?? o.createdAt;
        const d = dayKey(toDate(at, now));
        add(totals, d, "income.orderCommissionLkr", readNumber(o.orderCommissionLkr));
        add(totals, d, "income.ipgFeeLkr", readNumber(o.ipgFeeLkr));
        add(totals, d, "discountCost.couponsAndReferralsLkr", readNumber(o.discount));
      }
      return snap.size;
    });

    await step("refundedOrders", async () => {
      const snap = await db.collection("orders").where("paymentStatus", "==", "refunded").get();
      for (const doc of snap.docs) {
        const o = doc.data();
        const at = o.refundedAt ?? o.createdAt;
        add(totals, dayKey(toDate(at, now)), "outgoing.refundsPaidLkr", readNumber(o.total));
      }
      return snap.size;
    });

    await step("settledOrders", async () => {
      const snap = await db
        .collection("orders")
        .where("productCashStatus", "==", "settled_to_shop")
        .get();
      for (const doc of snap.docs) {
        const o = doc.data();
        const at = o.productCashSettledAt ?? o.createdAt;
        add(
          totals,
          dayKey(toDate(at, now)),
          "outgoing.codSettledToShopLkr",
          readNumber(o.productCashLkr),
        );
      }
      return snap.size;
    });

    await step("completedTrips", async () => {
      const {rideCommissionLkr} = await loadPlatformFeeConfig();
      const snap = await db.collection("trips").where("status", "==", "completed").get();
      for (const doc of snap.docs) {
        const t = doc.data();
        if (String(t.paymentStatus ?? "").trim().toLowerCase() !== "paid") {
          continue;
        }
        const fareLkr = readNumber(t.estimatedFareLkr);
        if (fareLkr <= 0) {
          continue;
        }
        const commissionLkr = Math.min(fareLkr, Math.max(0, rideCommissionLkr));
        const at = t.updatedAt ?? t.createdAt;
        add(totals, dayKey(toDate(at, now)), "income.rideCommissionLkr", commissionLkr);
      }
      return snap.size;
    });

    await step("paidWithdrawals", async () => {
      const snap = await db.collectionGroup("withdrawals").where("status", "==", "paid").get();
      for (const doc of snap.docs) {
        const w = doc.data();
        const at = w.processedAt ?? w.createdAt;
        add(
          totals,
          dayKey(toDate(at, now)),
          "outgoing.riderWithdrawalsPaidLkr",
          readNumber(w.amountLkr),
        );
      }
      return snap.size;
    });

    await step("paidPayouts", async () => {
      const snap = await db.collectionGroup("payouts").where("status", "==", "paid").get();
      for (const doc of snap.docs) {
        const p = doc.data();
        const at = p.processedAt ?? p.createdAt;
        add(
          totals,
          dayKey(toDate(at, now)),
          "outgoing.vendorPayoutsPaidLkr",
          readNumber(p.amountLkr),
        );
      }
      return snap.size;
    });

    await step("paidInvoices", async () => {
      const snap = await db.collectionGroup("monthly_invoices").where("status", "==", "paid").get();
      for (const doc of snap.docs) {
        const inv = doc.data();
        add(
          totals,
          dayKey(toDate(inv.paidAt, now)),
          "income.monthlyInvoiceLkr",
          readNumber(inv.feeLkr),
        );
      }
      return snap.size;
    });

    const entries = Array.from(totals.entries());
    const ref = db.collection("platform_daily_cashflow");
    for (let i = 0; i < entries.length; i += BATCH_SIZE) {
      const chunk = entries.slice(i, i + BATCH_SIZE);
      const batch = db.batch();
      for (const [docId, increments] of chunk) {
        const incrementFields = Object.fromEntries(
          Object.entries(increments).map(([key, value]) => [
            key,
            FieldValue.increment(value),
          ]),
        );
        batch.set(
          ref.doc(docId),
          {date: docId, ...incrementFields, updatedAt: FieldValue.serverTimestamp()},
          {merge: true},
        );
      }
      await batch.commit();
    }

    const hasFailures = Object.keys(failedSteps).length > 0;
    // Only mark fully complete if every step succeeded — a partial run
    // (e.g. a collection-group index still building) can be safely
    // re-run: FieldValue.increment only double-counts a step that
    // actually wrote data, and no step here writes twice for the same
    // event within one run.
    if (!hasFailures) {
      await markerRef.set({
        completedAt: FieldValue.serverTimestamp(),
        byUid: request.auth.uid,
        daysWritten: entries.length,
      });
    }

    logger.info("backfillPlatformCashFlow complete", {
      days: entries.length,
      scannedCounts,
      failedSteps,
      markedComplete: !hasFailures,
    });

    return {daysWritten: entries.length, scannedCounts, failedSteps, markedComplete: !hasFailures};
  },
);
