import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {assertAdmin} from "./adminAuth";
import {loadPlatformFeeConfig} from "./platformConfig";
import {counterPatch, readCashCounters, REMITTABLE_PRODUCT_CASH} from "./riderCash";
import {evaluateCashHold} from "./riderCashLogic";

const REGION = "asia-south1";

/**
 * Admin records that product cash was physically received from the rider.
 * owed | remittance_requested → remitted_to_admin
 *
 * Accepts "owed" directly (not just "remittance_requested") so an admin who
 * collects cash from a rider in person — without the rider having gone
 * through the app's request-a-handover flow — can still record it here.
 * Same allowance the bulk cash-settlement flow already has
 * (adminConfirmCashSettlement in riderCash.ts).
 *
 * Also settles this order's own `cash_ledger` entry and decrements the
 * rider's `cashInHandLkr` / `cashOwedToAdminLkr` counters — otherwise this
 * shortcut (bypassing the rider's own handover flow) left the order marked
 * remitted while the rider app kept showing that same cash as still owed,
 * and it would get asked for again on the rider's next real handover.
 */
export const adminMarkProductCashRemitted = onCall(
  {region: REGION},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in as admin.");
    }
    await assertAdmin(request.auth.uid);
    const orderId = String(request.data?.orderId ?? "").trim();
    if (!orderId) {
      throw new HttpsError("invalid-argument", "orderId is required.");
    }

    const db = getFirestore();
    const ref = db.collection("orders").doc(orderId);
    const maxCashInHandLkr = (await loadPlatformFeeConfig()).maxRiderCashInHandLkr;

    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) {
        throw new HttpsError("not-found", "Order not found.");
      }
      const data = snap.data() ?? {};
      const status = String(data.productCashStatus ?? "").trim();
      if (!REMITTABLE_PRODUCT_CASH.has(status)) {
        throw new HttpsError(
          "failed-precondition",
          `Expected productCashStatus "owed" or "remittance_requested", got "${status || "none"}".`,
        );
      }

      const riderId = String(
        data.productCashRiderId ?? data.riderId ?? data.assignedRiderId ?? "",
      ).trim();
      const riderRef = riderId ? db.collection("riders").doc(riderId) : null;
      const ledgerRef = riderRef ?
        riderRef.collection("cash_ledger").doc(`order_${orderId}`) :
        null;
      const [riderSnap, ledgerSnap] = riderRef && ledgerRef ?
        await tx.getAll(riderRef, ledgerRef) :
        [null, null];

      if (ledgerSnap?.exists) {
        const entryStatus = String(ledgerSnap.data()?.status ?? "").trim();
        if (entryStatus === "pending_settlement") {
          throw new HttpsError(
            "failed-precondition",
            "This rider already has a handover pending for this cash — " +
              "confirm or reject it from the Rider cash page instead.",
          );
        }
        if (entryStatus === "open") {
          const entry = ledgerSnap.data() ?? {};
          const wasHeld = riderSnap?.data()?.cashHoldActive === true;
          const current = readCashCounters(riderSnap?.data());
          const counters = {
            cashInHandLkr: Math.max(
              0,
              current.cashInHandLkr - Math.round(Number(entry.cashLkr) || 0),
            ),
            cashOwedToAdminLkr: Math.max(
              0,
              current.cashOwedToAdminLkr - Math.round(Number(entry.owedLkr) || 0),
            ),
            cashPendingSettlementLkr: current.cashPendingSettlementLkr,
            cashAdvanceCreditLkr: current.cashAdvanceCreditLkr,
          };
          const holdActive = evaluateCashHold({
            cashInHandLkr: counters.cashInHandLkr,
            maxCashInHandLkr,
          });
          tx.update(ledgerRef!, {
            status: "settled",
            settledAt: FieldValue.serverTimestamp(),
          });
          tx.set(riderRef!, counterPatch(counters, holdActive, wasHeld), {
            merge: true,
          });
        }
      }

      tx.update(ref, {
        productCashStatus: "remitted_to_admin",
        productCashRemittedAt: FieldValue.serverTimestamp(),
        productCashRemittedBy: request.auth!.uid,
        productCashRemittanceConfirmedAt: FieldValue.serverTimestamp(),
        productCashRemittanceConfirmedBy: request.auth!.uid,
      });
    });

    return {orderId, productCashStatus: "remitted_to_admin"};
  },
);

/**
 * Assigned rider requests an Admin handover confirmation.
 * owed → remittance_requested (only for productCashRiderId == caller).
 *
 * The rider cannot close their own cash debt. It remains outstanding until
 * an admin physically receives the money and calls
 * adminMarkProductCashRemitted.
 *
 * @deprecated Superseded by `riderRequestCashSettlement`, which hands over
 * every open cash entry — ride commission included — in one request and
 * advances these same order fields on confirmation. Kept so rider builds
 * shipped before that change keep working; the per-order UI is gone.
 */
export const riderMarkProductCashRemitted = onCall(
  {region: REGION},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in as rider.");
    }
    const riderUid = request.auth.uid;
    const orderId = String(request.data?.orderId ?? "").trim();
    if (!orderId) {
      throw new HttpsError("invalid-argument", "orderId is required.");
    }

    const db = getFirestore();
    const riderSnap = await db.collection("riders").doc(riderUid).get();
    if (!riderSnap.exists) {
      throw new HttpsError("permission-denied", "Rider profile required.");
    }

    const ref = db.collection("orders").doc(orderId);
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) {
        throw new HttpsError("not-found", "Order not found.");
      }
      const data = snap.data() ?? {};
      const cashRider = String(data.productCashRiderId ?? "").trim();
      if (!cashRider || cashRider !== riderUid) {
        throw new HttpsError(
          "permission-denied",
          "Only the rider who holds this product cash can mark it remitted.",
        );
      }
      const status = String(data.productCashStatus ?? "").trim();
      if (status !== "owed") {
        throw new HttpsError(
          "failed-precondition",
          `Expected productCashStatus "owed", got "${status || "none"}".`,
        );
      }
      tx.update(ref, {
        productCashStatus: "remittance_requested",
        productCashRemittanceRequestedAt: FieldValue.serverTimestamp(),
        productCashRemittanceRequestedBy: riderUid,
      });
    });

    return {orderId, productCashStatus: "remittance_requested"};
  },
);

/**
 * Admin records that product cash was paid/settled to the shop.
 * remitted_to_admin → settled_to_shop
 */
export const adminMarkProductCashSettledToShop = onCall(
  {region: REGION},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in as admin.");
    }
    await assertAdmin(request.auth.uid);
    const orderId = String(request.data?.orderId ?? "").trim();
    if (!orderId) {
      throw new HttpsError("invalid-argument", "orderId is required.");
    }

    const db = getFirestore();
    const ref = db.collection("orders").doc(orderId);
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) {
        throw new HttpsError("not-found", "Order not found.");
      }
      const data = snap.data() ?? {};
      const status = String(data.productCashStatus ?? "").trim();
      if (status !== "remitted_to_admin") {
        throw new HttpsError(
          "failed-precondition",
          `Expected productCashStatus "remitted_to_admin", got "${status || "none"}".`,
        );
      }
      tx.update(ref, {
        productCashStatus: "settled_to_shop",
        productCashSettledAt: FieldValue.serverTimestamp(),
        productCashSettledBy: request.auth!.uid,
      });
    });

    return {orderId, productCashStatus: "settled_to_shop"};
  },
);
