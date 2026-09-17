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

    const completedOrders = await db
      .collection("orders")
      .where("status", "in", ["completed", "delivered"])
      .get();
    for (const doc of completedOrders.docs) {
      const o = doc.data();
      const at = o.deliveredAt ?? o.completedAt ?? o.createdAt;
      const d = dayKey(toDate(at, now));
      add(totals, d, "income.orderCommissionLkr", readNumber(o.orderCommissionLkr));
      add(totals, d, "income.ipgFeeLkr", readNumber(o.ipgFeeLkr));
      add(totals, d, "discountCost.couponsAndReferralsLkr", readNumber(o.discount));
    }

    const refundedOrders = await db
      .collection("orders")
      .where("paymentStatus", "==", "refunded")
      .get();
    for (const doc of refundedOrders.docs) {
      const o = doc.data();
      const at = o.refundedAt ?? o.createdAt;
      add(totals, dayKey(toDate(at, now)), "outgoing.refundsPaidLkr", readNumber(o.total));
    }

    const settledOrders = await db
      .collection("orders")
      .where("productCashStatus", "==", "settled_to_shop")
      .get();
    for (const doc of settledOrders.docs) {
      const o = doc.data();
      const at = o.productCashSettledAt ?? o.createdAt;
      add(
        totals,
        dayKey(toDate(at, now)),
        "outgoing.codSettledToShopLkr",
        readNumber(o.productCashLkr),
      );
    }

    const {rideCommissionLkr} = await loadPlatformFeeConfig();
    const completedTrips = await db
      .collection("trips")
      .where("status", "==", "completed")
      .get();
    for (const doc of completedTrips.docs) {
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

    const paidWithdrawals = await db
      .collectionGroup("withdrawals")
      .where("status", "==", "paid")
      .get();
    for (const doc of paidWithdrawals.docs) {
      const w = doc.data();
      const at = w.processedAt ?? w.createdAt;
      add(
        totals,
        dayKey(toDate(at, now)),
        "outgoing.riderWithdrawalsPaidLkr",
        readNumber(w.amountLkr),
      );
    }

    const paidPayouts = await db
      .collectionGroup("payouts")
      .where("status", "==", "paid")
      .get();
    for (const doc of paidPayouts.docs) {
      const p = doc.data();
      const at = p.processedAt ?? p.createdAt;
      add(
        totals,
        dayKey(toDate(at, now)),
        "outgoing.vendorPayoutsPaidLkr",
        readNumber(p.amountLkr),
      );
    }

    const paidInvoices = await db
      .collectionGroup("monthly_invoices")
      .where("status", "==", "paid")
      .get();
    for (const doc of paidInvoices.docs) {
      const inv = doc.data();
      add(
        totals,
        dayKey(toDate(inv.paidAt, now)),
        "income.monthlyInvoiceLkr",
        readNumber(inv.feeLkr),
      );
    }

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

    await markerRef.set({
      completedAt: FieldValue.serverTimestamp(),
      byUid: request.auth.uid,
      daysWritten: entries.length,
    });

    logger.info("backfillPlatformCashFlow complete", {
      days: entries.length,
      ordersScanned: completedOrders.size + refundedOrders.size + settledOrders.size,
      tripsScanned: completedTrips.size,
      withdrawalsScanned: paidWithdrawals.size,
      payoutsScanned: paidPayouts.size,
      invoicesScanned: paidInvoices.size,
    });

    return {daysWritten: entries.length};
  },
);
