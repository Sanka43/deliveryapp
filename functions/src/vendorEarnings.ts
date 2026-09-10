import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {onDocumentUpdated} from "firebase-functions/v2/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {assertAdmin} from "./adminAuth";
import {writeVendorNotification} from "./orderNotifications";
import {
  applyWithdrawalSettlement,
  WalletNums,
  WithdrawalSettleAction,
} from "./riderEarnings";

const REGION = "asia-south1";
const MIN_PAYOUT_LKR = 1000;
const MAX_PAYOUT_LKR = 1000000;

function isPaidOnline(data: FirebaseFirestore.DocumentData): boolean {
  const paymentStatus = String(data.paymentStatus ?? "").trim().toLowerCase();
  const paymentProvider = String(data.paymentProvider ?? "").trim().toLowerCase();
  return paymentStatus === "paid" && paymentProvider === "payhere";
}

function vendorIdOf(data: FirebaseFirestore.DocumentData): string {
  return String(data.vendorId ?? data.vendorStoreId ?? "").trim();
}

function isTerminalSuccessStatus(status: unknown): boolean {
  const s = String(status ?? "").trim().toLowerCase();
  return s === "completed" || s === "delivered";
}

async function notifyVendorPayoutSettled(input: {
  vendorId: string;
  payoutId: string;
  action: WithdrawalSettleAction;
  amountLkr: number;
}): Promise<void> {
  const isPaid = input.action === "paid";
  const title = isPaid ? "Payout paid" : "Payout rejected";
  const amountLabel = `Rs. ${input.amountLkr.toFixed(0)}`;
  const body = isPaid ?
    `Your payout of ${amountLabel} was paid.` :
    `Your payout of ${amountLabel} was rejected and returned to your balance.`;

  await writeVendorNotification({
    vendorId: input.vendorId,
    notificationId: `payout_${input.payoutId}_${input.action}`,
    type: "payout_settled",
    title,
    body,
  });
}

/**
 * Server-authoritative vendor payout. Credits the vendor's withdrawable
 * balance exactly once when an order paid online (PayHere) reaches a
 * terminal success status (`completed` for self-pickup, `delivered` for
 * courier drop-off).
 *
 * Cash-on-delivery orders are deliberately excluded — that money never
 * reached the platform, it went to the rider at the door, and is already
 * tracked end-to-end by the `productCashStatus` ledger on the order
 * (owed -> remittance_requested -> remitted_to_admin -> settled_to_shop),
 * settled by admin outside this wallet. Crediting both here would double-pay
 * the vendor for the same sale.
 */
export const onOrderCompletedCreditVendor = onDocumentUpdated(
  {document: "orders/{orderId}", region: REGION},
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) {
      return;
    }
    if (isTerminalSuccessStatus(before.status) || !isTerminalSuccessStatus(after.status)) {
      return;
    }
    if (!isPaidOnline(after)) {
      return;
    }
    const vendorId = vendorIdOf(after);
    if (!vendorId) {
      logger.warn("Completed paid order has no vendorId; skipping credit", {
        orderId: event.params.orderId,
      });
      return;
    }

    // Same product-total formula as the shop app's `VendorPendingOrder.shopTotal`
    // and the COD `productCashLkr` field — sale price minus discount, excluding
    // delivery fee and the platform's order commission.
    const subtotal = Math.max(0, Math.round(Number(after.subtotal ?? 0)));
    const discount = Math.max(0, Math.round(Number(after.discount ?? 0)));
    const amountLkr = Math.max(0, subtotal - discount);
    if (amountLkr <= 0) {
      return;
    }

    const orderId = event.params.orderId;
    const db = getFirestore();
    const vendorRef = db.collection("vendors").doc(vendorId);
    const txnRef = vendorRef.collection("transactions").doc(`earning_${orderId}`);
    const walletRef = vendorRef.collection("wallet").doc("summary");
    const reference = String(after.trackingNumber ?? orderId);

    await db.runTransaction(async (tx) => {
      const existing = await tx.get(txnRef);
      if (existing.exists) {
        return;
      }
      const walletSnap = await tx.get(walletRef);
      const w = walletSnap.data() ?? {};

      tx.set(txnRef, {
        type: "order_earning",
        status: "completed",
        amountLkr,
        orderId,
        title: "Order sale",
        subtitle: reference,
        createdAt: FieldValue.serverTimestamp(),
      });
      tx.set(
        walletRef,
        {
          balanceLkr: Number(w.balanceLkr ?? 0) + amountLkr,
          pendingWithdrawalLkr: Number(w.pendingWithdrawalLkr ?? 0),
          lifetimeEarnedLkr: Number(w.lifetimeEarnedLkr ?? 0) + amountLkr,
          lifetimeWithdrawnLkr: Number(w.lifetimeWithdrawnLkr ?? 0),
          updatedAt: FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
    });

    logger.info("Recorded vendor order earning", {vendorId, orderId, amountLkr});
  },
);

/**
 * Server-validated vendor payout request. Verifies the shop is approved and
 * has sufficient balance, then atomically deducts the wallet and creates the
 * pending payout + ledger entry — mirrors `requestRiderWithdrawal`. Payout
 * details are supplied per-request rather than stored on the vendor profile,
 * same as the rider flow.
 */
export const requestVendorPayout = onCall({region: REGION}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in to request a payout.");
  }
  const vendorId = request.auth.uid;
  const amount = Math.round(Number(request.data?.amountLkr ?? 0));
  const method = String(request.data?.payoutMethod ?? "").trim().toLowerCase();
  const account = String(request.data?.payoutAccount ?? "").trim();
  const note = String(request.data?.note ?? "").trim().slice(0, 500);

  if (!Number.isFinite(amount) || amount < MIN_PAYOUT_LKR) {
    throw new HttpsError(
      "invalid-argument",
      `Minimum payout is Rs. ${MIN_PAYOUT_LKR}.`,
    );
  }
  if (amount > MAX_PAYOUT_LKR) {
    throw new HttpsError("invalid-argument", `Maximum payout is Rs. ${MAX_PAYOUT_LKR}.`);
  }
  if (method !== "bank" && method !== "mobile") {
    throw new HttpsError("invalid-argument", "Choose a valid payout method.");
  }
  if (account.length < 4 || account.length > 64) {
    throw new HttpsError("invalid-argument", "Enter valid payout details.");
  }

  const db = getFirestore();
  const vendorRef = db.collection("vendors").doc(vendorId);
  const vendorSnap = await vendorRef.get();
  if (!vendorSnap.exists) {
    throw new HttpsError("permission-denied", "Shop profile required.");
  }
  const approvalStatus = String(vendorSnap.data()?.approvalStatus ?? "")
    .trim()
    .toLowerCase();
  // Legacy shops predating approvalStatus keep working; a shop explicitly
  // pending/rejected cannot request a payout.
  if (approvalStatus && approvalStatus !== "approved") {
    throw new HttpsError(
      "permission-denied",
      "Your shop must be approved before requesting a payout.",
    );
  }

  const walletRef = vendorRef.collection("wallet").doc("summary");
  const payoutRef = vendorRef.collection("payouts").doc();
  const txnRef = vendorRef.collection("transactions").doc(`payout_${payoutRef.id}`);

  await db.runTransaction(async (tx) => {
    const walletSnap = await tx.get(walletRef);
    const w = walletSnap.data() ?? {};
    const balance = Number(w.balanceLkr ?? 0);
    if (amount > balance) {
      throw new HttpsError("failed-precondition", "Insufficient balance.");
    }

    tx.set(payoutRef, {
      vendorId,
      amountLkr: amount,
      status: "pending",
      payoutMethod: method,
      payoutAccount: account,
      ledgerTxnId: txnRef.id,
      ...(note ? {note} : {}),
      createdAt: FieldValue.serverTimestamp(),
    });
    tx.set(txnRef, {
      type: "payout",
      status: "pending",
      amountLkr: -amount,
      payoutId: payoutRef.id,
      title: "Payout request",
      subtitle: method,
      createdAt: FieldValue.serverTimestamp(),
    });
    tx.set(
      walletRef,
      {
        balanceLkr: balance - amount,
        pendingWithdrawalLkr: Number(w.pendingWithdrawalLkr ?? 0) + amount,
        lifetimeEarnedLkr: Number(w.lifetimeEarnedLkr ?? 0),
        lifetimeWithdrawnLkr: Number(w.lifetimeWithdrawnLkr ?? 0),
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
  });

  return {payoutId: payoutRef.id, status: "pending"};
});

function toHttpsError(e: unknown): never {
  const code = (e as {code?: string}).code;
  const message = e instanceof Error ? e.message : "Could not settle payout.";
  if (code === "invalid-argument" || code === "failed-precondition") {
    throw new HttpsError(code, message);
  }
  throw new HttpsError("internal", message);
}

/**
 * Admin marks a vendor payout paid (money sent to the shop) or rejected
 * (restore available balance). Idempotent for the same terminal status.
 * Reuses the same wallet-settlement math as `adminSettleRiderWithdrawal` —
 * the arithmetic doesn't care whose wallet it is.
 */
export const adminSettleVendorPayout = onCall({region: REGION}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in as admin.");
  }
  await assertAdmin(request.auth.uid);

  const vendorId = String(request.data?.vendorId ?? "").trim();
  const payoutId = String(request.data?.payoutId ?? "").trim();
  const actionRaw = String(request.data?.action ?? "").trim().toLowerCase();
  const action: WithdrawalSettleAction | "" =
    actionRaw === "paid" || actionRaw === "rejected" ? actionRaw : "";

  if (!vendorId || !payoutId || !action) {
    throw new HttpsError(
      "invalid-argument",
      "vendorId, payoutId, and action (paid|rejected) are required.",
    );
  }

  const db = getFirestore();
  const vendorRef = db.collection("vendors").doc(vendorId);
  const payoutRef = vendorRef.collection("payouts").doc(payoutId);
  const walletRef = vendorRef.collection("wallet").doc("summary");
  const txns = vendorRef.collection("transactions");

  try {
    const result = await db.runTransaction(async (tx) => {
      const [payoutSnap, walletSnap] = await Promise.all([
        tx.get(payoutRef),
        tx.get(walletRef),
      ]);
      if (!payoutSnap.exists) {
        throw new HttpsError("not-found", "Payout not found.");
      }
      const payout = payoutSnap.data() ?? {};
      const amount = Math.round(Number(payout.amountLkr ?? 0));
      const w = walletSnap.data() ?? {};
      const ledgerTxnId =
        String(payout.ledgerTxnId ?? "").trim() || `payout_${payoutId}`;
      const ledgerRef = txns.doc(ledgerTxnId);
      const ledgerSnap = await tx.get(ledgerRef);

      const wallet: WalletNums = {
        balanceLkr: Number(w.balanceLkr ?? 0),
        pendingWithdrawalLkr: Number(w.pendingWithdrawalLkr ?? 0),
        lifetimeEarnedLkr: Number(w.lifetimeEarnedLkr ?? 0),
        lifetimeWithdrawnLkr: Number(w.lifetimeWithdrawnLkr ?? 0),
      };
      const settlement = applyWithdrawalSettlement({
        action,
        status: String(payout.status ?? ""),
        amountLkr: amount,
        wallet,
      });

      if (settlement.alreadyDone) {
        return {alreadyDone: true, status: settlement.nextStatus, amountLkr: amount};
      }

      tx.update(payoutRef, {
        status: settlement.nextStatus,
        processedAt: FieldValue.serverTimestamp(),
        processedBy: request.auth!.uid,
        processedAction: action,
      });
      if (ledgerSnap.exists) {
        tx.update(ledgerRef, {
          status: settlement.ledgerStatus,
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
      tx.set(
        walletRef,
        {...settlement.wallet, updatedAt: FieldValue.serverTimestamp()},
        {merge: true},
      );
      return {alreadyDone: false, status: settlement.nextStatus, amountLkr: amount};
    });

    if (!result.alreadyDone) {
      await notifyVendorPayoutSettled({
        vendorId,
        payoutId,
        action,
        amountLkr: result.amountLkr,
      });
    }

    return {vendorId, payoutId, ...result};
  } catch (e) {
    if (e instanceof HttpsError) {
      throw e;
    }
    toHttpsError(e);
  }
});
