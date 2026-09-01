import {
  DocumentData,
  DocumentReference,
  DocumentSnapshot,
  FieldValue,
  getFirestore,
  Transaction,
} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {assertAdmin} from "./adminAuth";
import {loadPlatformFeeConfig} from "./platformConfig";
import {notifyRider} from "./riderNotify";
import {
  applyCashEntry,
  applyCashSettlement,
  CashEntryAmounts,
  CashSettlementAction,
  MAX_SETTLEMENT_ENTRIES,
  RiderCashCounters,
} from "./riderCashLogic";

const REGION = "asia-south1";

/** Product-cash states a settlement may advance to `remitted_to_admin`. */
const REMITTABLE_PRODUCT_CASH = new Set(["owed", "remittance_requested"]);

export type CashLedgerType = "ride_cash" | "order_cash";

function toWholeLkr(value: unknown): number {
  const n = Math.round(Number(value));
  return Number.isFinite(n) ? n : 0;
}

export function readCashCounters(
  data: DocumentData | undefined,
): RiderCashCounters {
  return {
    cashInHandLkr: toWholeLkr(data?.cashInHandLkr),
    cashOwedToAdminLkr: toWholeLkr(data?.cashOwedToAdminLkr),
    cashPendingSettlementLkr: toWholeLkr(data?.cashPendingSettlementLkr),
  };
}

/**
 * The rider-doc patch every counter change writes. `cashHoldSince` is stamped
 * when the hold starts and cleared when it lifts, so the admin panel can show
 * how long a rider has been blocked; callers delete the key from the patch
 * when an existing hold is merely continuing.
 */
function counterPatch(
  counters: RiderCashCounters,
  holdActive: boolean,
  wasHeld: boolean,
): Record<string, unknown> {
  return {
    cashInHandLkr: counters.cashInHandLkr,
    cashOwedToAdminLkr: counters.cashOwedToAdminLkr,
    cashPendingSettlementLkr: counters.cashPendingSettlementLkr,
    cashHoldActive: holdActive,
    ...(holdActive && !wasHeld ?
      {cashHoldSince: FieldValue.serverTimestamp()} :
      {}),
    ...(holdActive ? {} : {cashHoldSince: null}),
    cashUpdatedAt: FieldValue.serverTimestamp(),
  };
}

/**
 * Records one cash job on the rider's ledger and counters, inside a caller's
 * transaction. `riderData` must come from a `tx.get(riderRef)` the caller
 * already performed — every Firestore transaction read has to precede its
 * first write.
 *
 * Returns whether this entry is what pushed the rider over the limit, so the
 * caller can notify them once the transaction commits.
 */
export function stageCashEntry(
  tx: Transaction,
  args: {
    riderRef: DocumentReference;
    riderData: DocumentData | undefined;
    entryId: string;
    type: CashLedgerType;
    entry: CashEntryAmounts;
    title: string;
    subtitle: string;
    tripId?: string;
    orderId?: string;
    maxCashInHandLkr: number;
  },
): {holdActivated: boolean; counters: RiderCashCounters} {
  const wasHeld = args.riderData?.cashHoldActive === true;
  const {counters, holdActive} = applyCashEntry({
    counters: readCashCounters(args.riderData),
    entry: args.entry,
    maxCashInHandLkr: args.maxCashInHandLkr,
  });

  tx.set(
    args.riderRef.collection("cash_ledger").doc(args.entryId),
    {
      type: args.type,
      status: "open",
      cashLkr: args.entry.cashLkr,
      owedLkr: args.entry.owedLkr,
      breakdown: args.entry.breakdown,
      title: args.title,
      subtitle: args.subtitle,
      ...(args.tripId ? {tripId: args.tripId} : {}),
      ...(args.orderId ? {orderId: args.orderId} : {}),
      createdAt: FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  tx.set(args.riderRef, counterPatch(counters, holdActive, wasHeld), {
    merge: true,
  });

  return {holdActivated: holdActive && !wasHeld, counters};
}

/** Rider push + inbox for the moment new jobs stop being claimable. */
export async function notifyCashHoldStarted(input: {
  riderId: string;
  cashInHandLkr: number;
  owedLkr: number;
}): Promise<void> {
  await notifyRider({
    riderId: input.riderId,
    notificationId: `cash_hold_${input.cashInHandLkr}`,
    type: "cash_hold_started",
    title: "Cash limit reached",
    body:
      `You are holding Rs. ${input.cashInHandLkr}. Hand over Rs. ` +
      `${input.owedLkr} to admin to start receiving jobs again.`,
    amountLkr: input.owedLkr,
  });
}

/**
 * Rider tells admin they are handing over the cash they owe. Snapshots every
 * open ledger entry into one settlement so the amounts can't drift while the
 * handover is in flight, and so entries recorded afterwards stay outstanding.
 *
 * The rider can never close their own debt — this only moves entries to
 * `pending_settlement`; the hold lifts on adminConfirmCashSettlement.
 */
export const riderRequestCashSettlement = onCall(
  {region: REGION},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in as rider.");
    }
    const riderId = request.auth.uid;
    const methodRaw = String(request.data?.method ?? "bank")
      .trim()
      .toLowerCase();
    const method = methodRaw === "cash" ? "cash" : "bank";
    const reference = String(request.data?.reference ?? "").trim().slice(0, 200);

    const db = getFirestore();
    const riderRef = db.collection("riders").doc(riderId);
    const ledgerCol = riderRef.collection("cash_ledger");
    const settlementsCol = riderRef.collection("cash_settlements");
    const settlementRef = settlementsCol.doc();

    const result = await db.runTransaction(async (tx) => {
      const riderSnap = await tx.get(riderRef);
      if (!riderSnap.exists) {
        throw new HttpsError("permission-denied", "Rider profile required.");
      }
      const openRequests = await tx.get(
        settlementsCol.where("status", "==", "requested").limit(1),
      );
      if (!openRequests.empty) {
        throw new HttpsError(
          "failed-precondition",
          "You already have a handover waiting for admin confirmation.",
        );
      }
      const entries = await tx.get(
        ledgerCol
          .where("status", "==", "open")
          .orderBy("createdAt", "asc")
          .limit(MAX_SETTLEMENT_ENTRIES),
      );
      if (entries.empty) {
        throw new HttpsError(
          "failed-precondition",
          "You have no collected cash to hand over.",
        );
      }

      let amountLkr = 0;
      let cashCoveredLkr = 0;
      let productCashLkr = 0;
      let serviceChargeLkr = 0;
      let rideCommissionLkr = 0;
      const entryIds: string[] = [];
      const orderIds: string[] = [];
      const tripIds: string[] = [];

      for (const doc of entries.docs) {
        const d = doc.data();
        const owed = toWholeLkr(d.owedLkr);
        amountLkr += owed;
        cashCoveredLkr += toWholeLkr(d.cashLkr);
        entryIds.push(doc.id);

        const breakdown = d.breakdown as Record<string, unknown> | undefined;
        if (breakdown && typeof breakdown === "object") {
          // Post-migration entry: trust its own stored split.
          productCashLkr += toWholeLkr(breakdown.productCashLkr);
          serviceChargeLkr += toWholeLkr(breakdown.serviceChargeLkr);
          rideCommissionLkr += toWholeLkr(breakdown.rideCommissionLkr);
        } else if (d.type === "order_cash") {
          // Pre-migration order entry: owedLkr was 100% product cash back then.
          productCashLkr += owed;
        } else {
          // Pre-migration ride entry: owedLkr was 100% commission.
          rideCommissionLkr += owed;
        }

        if (d.type === "order_cash") {
          const orderId = String(d.orderId ?? "").trim();
          if (orderId) {
            orderIds.push(orderId);
          }
        } else {
          const tripId = String(d.tripId ?? "").trim();
          if (tripId) {
            tripIds.push(tripId);
          }
        }
      }

      for (const doc of entries.docs) {
        tx.update(doc.ref, {
          status: "pending_settlement",
          settlementId: settlementRef.id,
        });
      }

      tx.set(settlementRef, {
        riderId,
        amountLkr,
        cashCoveredLkr,
        breakdown: {productCashLkr, serviceChargeLkr, rideCommissionLkr},
        entryIds,
        orderIds,
        tripIds,
        entryCount: entryIds.length,
        status: "requested",
        method,
        ...(reference ? {reference} : {}),
        requestedAt: FieldValue.serverTimestamp(),
        requestedBy: riderId,
      });

      tx.set(
        riderRef,
        {
          cashPendingSettlementLkr: amountLkr,
          cashUpdatedAt: FieldValue.serverTimestamp(),
        },
        {merge: true},
      );

      return {amountLkr, cashCoveredLkr, entryCount: entryIds.length};
    });

    logger.info("Rider requested cash settlement", {
      riderId,
      settlementId: settlementRef.id,
      ...result,
    });
    return {settlementId: settlementRef.id, status: "requested", ...result};
  },
);

async function settleCashRequest(args: {
  adminUid: string;
  riderId: string;
  settlementId: string;
  action: CashSettlementAction;
  reason?: string;
  maxCashInHandLkr: number;
}): Promise<{alreadyDone: boolean; amountLkr: number; holdActive: boolean}> {
  const db = getFirestore();
  const riderRef = db.collection("riders").doc(args.riderId);
  const settlementRef = riderRef
    .collection("cash_settlements")
    .doc(args.settlementId);

  return db.runTransaction(async (tx) => {
    const settlementSnap = await tx.get(settlementRef);
    if (!settlementSnap.exists) {
      throw new HttpsError("not-found", "Settlement not found.");
    }
    const settlement = settlementSnap.data() ?? {};
    const riderSnap = await tx.get(riderRef);
    if (!riderSnap.exists) {
      throw new HttpsError("not-found", "Rider not found.");
    }

    const entryIds: string[] = Array.isArray(settlement.entryIds) ?
      settlement.entryIds.map((id: unknown) => String(id)) :
      [];
    const orderIds: string[] = Array.isArray(settlement.orderIds) ?
      settlement.orderIds.map((id: unknown) => String(id)) :
      [];

    // Orders are only re-read (and re-stamped) on confirm; a reject leaves
    // their product-cash state exactly as it was.
    const orderSnaps: DocumentSnapshot[] =
      args.action === "confirmed" && orderIds.length > 0 ?
        await tx.getAll(
          ...orderIds.map((id) => db.collection("orders").doc(id)),
        ) :
        [];

    let outcome;
    try {
      outcome = applyCashSettlement({
        action: args.action,
        status: String(settlement.status ?? ""),
        amountLkr: toWholeLkr(settlement.amountLkr),
        cashCoveredLkr: toWholeLkr(settlement.cashCoveredLkr),
        counters: readCashCounters(riderSnap.data()),
        maxCashInHandLkr: args.maxCashInHandLkr,
      });
    } catch (e) {
      const code = (e as {code?: string}).code;
      const message = e instanceof Error ? e.message : "Could not settle.";
      if (code === "invalid-argument" || code === "failed-precondition") {
        throw new HttpsError(code, message);
      }
      throw new HttpsError("internal", message);
    }

    if (outcome.alreadyDone) {
      return {
        alreadyDone: true,
        amountLkr: toWholeLkr(settlement.amountLkr),
        holdActive: outcome.holdActive,
      };
    }

    const confirmed = args.action === "confirmed";
    tx.update(settlementRef, {
      status: outcome.nextStatus,
      ...(confirmed ?
        {
          confirmedAt: FieldValue.serverTimestamp(),
          confirmedBy: args.adminUid,
        } :
        {
          rejectedAt: FieldValue.serverTimestamp(),
          rejectedBy: args.adminUid,
          rejectReason: args.reason ?? "",
        }),
    });

    for (const entryId of entryIds) {
      tx.update(riderRef.collection("cash_ledger").doc(entryId), {
        status: confirmed ? "settled" : "open",
        ...(confirmed ?
          {settledAt: FieldValue.serverTimestamp()} :
          {settlementId: FieldValue.delete()}),
      });
    }

    if (confirmed) {
      for (const snap of orderSnaps) {
        if (!snap.exists) {
          continue;
        }
        const status = String(snap.data()?.productCashStatus ?? "").trim();
        if (!REMITTABLE_PRODUCT_CASH.has(status)) {
          continue;
        }
        tx.update(snap.ref, {
          productCashStatus: "remitted_to_admin",
          productCashRemittedAt: FieldValue.serverTimestamp(),
          productCashRemittedBy: args.adminUid,
          productCashRemittanceConfirmedAt: FieldValue.serverTimestamp(),
          productCashRemittanceConfirmedBy: args.adminUid,
        });
      }

      tx.set(
        riderRef
          .collection("transactions")
          .doc(`cash_settlement_${args.settlementId}`),
        {
          type: "cash_settlement",
          status: "completed",
          amountLkr: -toWholeLkr(settlement.amountLkr),
          settlementId: args.settlementId,
          title: "Cash handed to admin",
          subtitle: String(settlement.method ?? "bank"),
          createdAt: FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
    }

    const wasHeld = riderSnap.data()?.cashHoldActive === true;
    tx.set(riderRef, counterPatch(outcome.counters, outcome.holdActive, wasHeld), {
      merge: true,
    });

    return {
      alreadyDone: false,
      amountLkr: toWholeLkr(settlement.amountLkr),
      holdActive: outcome.holdActive,
    };
  });
}

async function loadMaxCashInHandLkr(): Promise<number> {
  const cfg = await loadPlatformFeeConfig();
  return cfg.maxRiderCashInHandLkr;
}

/**
 * Admin records that the rider's cash physically arrived. Clears the covered
 * ledger entries, advances any product cash on the covered orders to
 * `remitted_to_admin`, and lifts the hold.
 */
export const adminConfirmCashSettlement = onCall(
  {region: REGION},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in as admin.");
    }
    await assertAdmin(request.auth.uid);
    const riderId = String(request.data?.riderId ?? "").trim();
    const settlementId = String(request.data?.settlementId ?? "").trim();
    if (!riderId || !settlementId) {
      throw new HttpsError(
        "invalid-argument",
        "riderId and settlementId are required.",
      );
    }

    const result = await settleCashRequest({
      adminUid: request.auth.uid,
      riderId,
      settlementId,
      action: "confirmed",
      maxCashInHandLkr: await loadMaxCashInHandLkr(),
    });

    if (!result.alreadyDone) {
      await notifyRider({
        riderId,
        notificationId: `cash_settlement_${settlementId}_confirmed`,
        type: "cash_settlement_confirmed",
        title: "Cash settled",
        body: result.holdActive ?
          `Admin received Rs. ${result.amountLkr}. You are still over the ` +
            "cash limit — hand over the rest to start receiving jobs again." :
          `Admin received Rs. ${result.amountLkr}. You can accept rides again.`,
        amountLkr: result.amountLkr,
      });
    }

    return {riderId, settlementId, status: "confirmed", ...result};
  },
);

/**
 * Admin rejects a handover that never arrived. Entries go back to `open` so
 * the rider can request again; the hold is untouched.
 */
export const adminRejectCashSettlement = onCall(
  {region: REGION},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in as admin.");
    }
    await assertAdmin(request.auth.uid);
    const riderId = String(request.data?.riderId ?? "").trim();
    const settlementId = String(request.data?.settlementId ?? "").trim();
    const reason = String(request.data?.reason ?? "").trim().slice(0, 300);
    if (!riderId || !settlementId) {
      throw new HttpsError(
        "invalid-argument",
        "riderId and settlementId are required.",
      );
    }

    const result = await settleCashRequest({
      adminUid: request.auth.uid,
      riderId,
      settlementId,
      action: "rejected",
      reason,
      maxCashInHandLkr: await loadMaxCashInHandLkr(),
    });

    if (!result.alreadyDone) {
      await notifyRider({
        riderId,
        notificationId: `cash_settlement_${settlementId}_rejected`,
        type: "cash_settlement_rejected",
        title: "Handover not confirmed",
        body: reason ?
          `Admin did not confirm your Rs. ${result.amountLkr} handover: ${reason}` :
          `Admin did not confirm your Rs. ${result.amountLkr} handover.`,
        amountLkr: result.amountLkr,
      });
    }

    return {riderId, settlementId, status: "rejected", ...result};
  },
);
