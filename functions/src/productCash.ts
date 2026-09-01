import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {assertAdmin} from "./adminAuth";

const REGION = "asia-south1";

/**
 * Admin records that product cash was physically received from the rider.
 * remittance_requested → remitted_to_admin
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
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) {
        throw new HttpsError("not-found", "Order not found.");
      }
      const data = snap.data() ?? {};
      const status = String(data.productCashStatus ?? "").trim();
      if (status !== "remittance_requested") {
        throw new HttpsError(
          "failed-precondition",
          `Expected productCashStatus "remittance_requested", got "${status || "none"}".`,
        );
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
