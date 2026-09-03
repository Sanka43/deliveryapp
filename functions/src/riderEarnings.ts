import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {onDocumentUpdated} from "firebase-functions/v2/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {assertAdmin} from "./adminAuth";
import {loadPlatformFeeConfig} from "./platformConfig";
import {notifyCashHoldStarted, stageCashEntry} from "./riderCash";
import {cashEntryForOrder, cashEntryForTrip} from "./riderCashLogic";
import {
  sendPushToRider,
  writeRiderInboxNotification,
} from "./riderNotify";

const REGION = "asia-south1";
const MIN_WITHDRAWAL_LKR = 500;
const MAX_WITHDRAWAL_LKR = 500000;
const COLOMBO_OFFSET_MS = 5.5 * 60 * 60 * 1000;

async function notifyRiderWithdrawalSettled(input: {
  riderId: string;
  withdrawalId: string;
  action: WithdrawalSettleAction;
  amountLkr: number;
}): Promise<void> {
  const isPaid = input.action === "paid";
  const title = isPaid ? "Withdrawal paid" : "Withdrawal rejected";
  const amountLabel = `Rs. ${input.amountLkr.toFixed(0)}`;
  const body = isPaid ?
    `Your withdrawal of ${amountLabel} was paid.` :
    `Your withdrawal of ${amountLabel} was rejected and returned to your balance.`;
  const notificationId = `withdrawal_${input.withdrawalId}_${input.action}`;

  await writeRiderInboxNotification({
    riderId: input.riderId,
    notificationId,
    type: "withdrawal_settled",
    title,
    body,
    amountLkr: input.amountLkr,
  });
  await sendPushToRider({
    riderId: input.riderId,
    title,
    body,
    type: "withdrawal_settled",
  });
}

function pad2(n: number): string {
  return n.toString().padStart(2, "0");
}

/**
 * Aggregate period keys in Asia/Colombo wall-clock time. Matches the rider
 * app's RiderEarningsPeriodKeys format so historical docs stay consistent.
 */
function periodKeys(at: Date): {daily: string; weekly: string; monthly: string} {
  const shifted = new Date(at.getTime() + COLOMBO_OFFSET_MS);
  const year = shifted.getUTCFullYear();
  const month = shifted.getUTCMonth() + 1;
  const day = shifted.getUTCDate();
  const weekday = ((shifted.getUTCDay() + 6) % 7) + 1; // Mon=1 .. Sun=7

  const monday = new Date(Date.UTC(year, month - 1, day));
  monday.setUTCDate(monday.getUTCDate() - (weekday - 1));
  const startYear = monday.getUTCFullYear();
  const startOfYear = Date.UTC(startYear, 0, 1);
  const dayOfYear = Math.floor((monday.getTime() - startOfYear) / 86400000) + 1;
  const week = Math.floor((dayOfYear - 1 + 10) / 7);

  return {
    daily: `daily_${year}-${pad2(month)}-${pad2(day)}`,
    weekly: `weekly_${startYear}-W${pad2(week)}`,
    monthly: `monthly_${year}-${pad2(month)}`,
  };
}

/**
 * Server-authoritative delivery payout. Credits the assigned rider exactly
 * once when an order transitions to `delivered`, using the order's own
 * `deliveryFee` minus the platform's flat `orderRiderCommissionLkr`. Clients
 * can no longer write wallet/earnings docs, so this is the only earnings
 * source of truth.
 *
 * The wallet only holds what the *platform* owes the rider. On a COD order
 * the rider walked away with the customer's cash — delivery fee included — so
 * the net (fee minus commission) is recorded as earned but never credited to
 * the withdrawable balance; the collected cash goes on the rider's cash
 * ledger instead, with the commission marked owed to admin alongside the shop
 * product cost and service charge.
 */
export const onOrderDeliveredCreditRider = onDocumentUpdated(
  {document: "orders/{orderId}", region: REGION},
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) {
      return;
    }
    const beforeStatus = String(before.status ?? "").trim().toLowerCase();
    const afterStatus = String(after.status ?? "").trim().toLowerCase();
    if (afterStatus !== "delivered" || beforeStatus === "delivered") {
      return;
    }

    const orderId = event.params.orderId;
    const riderId = String(after.riderId ?? after.assignedRiderId ?? "").trim();
    if (!riderId) {
      logger.warn("Delivered order has no rider; skipping credit", {orderId});
      return;
    }
    const amount = Math.round(Number(after.deliveryFee ?? 0));
    const {orderRiderCommissionLkr, maxRiderCashInHandLkr} =
      await loadPlatformFeeConfig();
    const cashEntry = cashEntryForOrder({
      amountDueFromCustomerLkr: after.amountDueFromCustomer,
      totalLkr: after.total,
      productCashLkr: after.productCashLkr,
      serviceChargeLkr: after.serviceCharge,
      paymentStatus: after.paymentStatus,
      riderCommissionLkr: orderRiderCommissionLkr,
    });
    if ((!Number.isFinite(amount) || amount <= 0) && cashEntry == null) {
      logger.info("Delivered order has no fee and no cash; nothing to record", {
        orderId,
        riderId,
      });
      return;
    }

    // Commission comes out of the delivery fee regardless of who collected
    // it — a PayHere order credits the net to the wallet, a cash order marks
    // the same slice owed to admin via cashEntry above.
    const commissionLkr = Math.min(
      Math.max(amount, 0),
      Math.max(0, orderRiderCommissionLkr),
    );
    const netEarningLkr = Math.max(amount, 0) - commissionLkr;

    const db = getFirestore();
    const riderRef = db.collection("riders").doc(riderId);
    const txnRef = riderRef.collection("transactions").doc(`earning_${orderId}`);
    const walletRef = riderRef.collection("wallet").doc("summary");
    const at = event.data?.after.updateTime?.toDate() ?? new Date();
    const keys = periodKeys(at);
    const storeName = String(after.storeName ?? "Delivery");
    const reference = String(after.trackingNumber ?? orderId);

    const outcome = await db.runTransaction(async (tx) => {
      const existing = await tx.get(txnRef);
      if (existing.exists) {
        return null;
      }
      const walletSnap = await tx.get(walletRef);
      const w = walletSnap.data() ?? {};
      const riderSnap = cashEntry == null ? null : await tx.get(riderRef);

      tx.set(txnRef, {
        type: "delivery_earning",
        status: "completed",
        amountLkr: netEarningLkr,
        feeLkr: amount,
        commissionLkr,
        collectedInCash: cashEntry != null,
        orderId,
        title: storeName,
        subtitle: reference,
        createdAt: FieldValue.serverTimestamp(),
      });

      // Cash orders paid the rider at the door — crediting the withdrawable
      // balance too would pay the delivery fee out twice.
      if (cashEntry == null && netEarningLkr > 0) {
        tx.set(
          walletRef,
          {
            balanceLkr: Number(w.balanceLkr ?? 0) + netEarningLkr,
            pendingWithdrawalLkr: Number(w.pendingWithdrawalLkr ?? 0),
            lifetimeEarnedLkr: Number(w.lifetimeEarnedLkr ?? 0) + netEarningLkr,
            lifetimeWithdrawnLkr: Number(w.lifetimeWithdrawnLkr ?? 0),
            updatedAt: FieldValue.serverTimestamp(),
          },
          {merge: true},
        );
      }

      if (netEarningLkr > 0) {
        const aggregates: Array<[string, string]> = [
          [keys.daily, "daily"],
          [keys.weekly, "weekly"],
          [keys.monthly, "monthly"],
        ];
        for (const [key, periodType] of aggregates) {
          tx.set(
            riderRef.collection("earnings_aggregates").doc(key),
            {
              periodType,
              totalLkr: FieldValue.increment(netEarningLkr),
              tripCount: FieldValue.increment(1),
              updatedAt: FieldValue.serverTimestamp(),
            },
            {merge: true},
          );
        }
      }

      if (cashEntry == null) {
        return null;
      }
      return stageCashEntry(tx, {
        riderRef,
        riderData: riderSnap?.data(),
        entryId: `order_${orderId}`,
        type: "order_cash",
        entry: cashEntry,
        title: storeName,
        subtitle: reference,
        orderId,
        maxCashInHandLkr: maxRiderCashInHandLkr,
      });
    });

    logger.info("Recorded rider delivery earning", {
      riderId,
      orderId,
      amount,
      commissionLkr,
      netEarningLkr,
      cashCollectedLkr: cashEntry?.cashLkr ?? 0,
    });

    if (outcome?.holdActivated) {
      await notifyCashHoldStarted({
        riderId,
        cashInHandLkr: outcome.counters.cashInHandLkr,
        owedLkr: outcome.counters.cashOwedToAdminLkr,
      });
    }
  },
);

/**
 * Credits the assigned rider once a passenger trip is both `completed` AND
 * paid. Idempotent via earning_trip_{id}.
 *
 * The rider earns `estimatedFareLkr` minus the flat `rideCommissionLkr` the
 * platform keeps. Where that money sits depends on who collected it: a
 * PayHere fare reached the platform, so the net lands in the withdrawable
 * wallet; a cash fare went straight into the rider's pocket, so nothing is
 * credited and instead the full fare goes on their cash ledger with the
 * commission marked as owed to admin.
 *
 * Cash trips reach this state in a single write (`completeCashOrRideTrip`
 * sets status:'completed' + paymentStatus:'paid' together), so this fires
 * once, right at completion. PayHere trips are deliberately paid *after*
 * the ride ends (`markTripPaidAfterCompletion`), so this Firestore trigger
 * intentionally re-evaluates on that later write too — the rider's wallet
 * is credited only once the passenger has actually paid, not the instant
 * the ride finishes, closing the gap where a rider was paid out for a
 * PayHere fare the passenger never completed.
 */
export const onTripCompletedCreditRider = onDocumentUpdated(
  {document: "trips/{tripId}", region: REGION},
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) {
      return;
    }
    const afterStatus = String(after.status ?? "").trim().toLowerCase();
    const afterPaymentStatus = String(after.paymentStatus ?? "").trim().toLowerCase();
    if (afterStatus !== "completed" || afterPaymentStatus !== "paid") {
      return;
    }
    const beforeStatus = String(before.status ?? "").trim().toLowerCase();
    const beforePaymentStatus = String(before.paymentStatus ?? "").trim().toLowerCase();
    if (beforeStatus === "completed" && beforePaymentStatus === "paid") {
      return;
    }

    const tripId = event.params.tripId;
    const riderId = String(after.riderId ?? after.assignedRiderId ?? "").trim();
    if (!riderId) {
      logger.warn("Completed trip has no rider; skipping credit", {tripId});
      return;
    }
    const fareLkr = Math.round(Number(after.estimatedFareLkr ?? 0));
    if (!Number.isFinite(fareLkr) || fareLkr <= 0) {
      logger.info("Completed trip has no fare; nothing to credit", {tripId, riderId});
      return;
    }

    const {rideCommissionLkr, maxRiderCashInHandLkr} =
      await loadPlatformFeeConfig();
    const commissionLkr = Math.min(fareLkr, Math.max(0, rideCommissionLkr));
    const netEarningLkr = fareLkr - commissionLkr;
    const cashEntry = cashEntryForTrip({
      fareLkr,
      commissionLkr: rideCommissionLkr,
      paymentMethod: after.paymentMethod,
    });

    const db = getFirestore();
    const riderRef = db.collection("riders").doc(riderId);
    const txnRef = riderRef.collection("transactions").doc(`earning_trip_${tripId}`);
    const walletRef = riderRef.collection("wallet").doc("summary");
    const at = event.data?.after.updateTime?.toDate() ?? new Date();
    const keys = periodKeys(at);
    const pickupLabel = String(
      (after.pickup as {label?: string} | undefined)?.label ?? "Ride",
    );

    const outcome = await db.runTransaction(async (tx) => {
      const existing = await tx.get(txnRef);
      if (existing.exists) {
        return null;
      }
      const walletSnap = await tx.get(walletRef);
      const w = walletSnap.data() ?? {};
      const riderSnap = cashEntry == null ? null : await tx.get(riderRef);

      tx.set(txnRef, {
        type: "ride_earning",
        status: "completed",
        amountLkr: netEarningLkr,
        fareLkr,
        commissionLkr,
        collectedInCash: cashEntry != null,
        tripId,
        title: pickupLabel,
        subtitle: String(after.vehicleType ?? tripId),
        createdAt: FieldValue.serverTimestamp(),
      });

      // Cash fares never touch the withdrawable balance — the rider was paid
      // in full at the kerb and owes the commission back to admin.
      if (cashEntry == null && netEarningLkr > 0) {
        tx.set(
          walletRef,
          {
            balanceLkr: Number(w.balanceLkr ?? 0) + netEarningLkr,
            pendingWithdrawalLkr: Number(w.pendingWithdrawalLkr ?? 0),
            lifetimeEarnedLkr: Number(w.lifetimeEarnedLkr ?? 0) + netEarningLkr,
            lifetimeWithdrawnLkr: Number(w.lifetimeWithdrawnLkr ?? 0),
            updatedAt: FieldValue.serverTimestamp(),
          },
          {merge: true},
        );
      }

      const aggregates: Array<[string, string]> = [
        [keys.daily, "daily"],
        [keys.weekly, "weekly"],
        [keys.monthly, "monthly"],
      ];
      for (const [key, periodType] of aggregates) {
        tx.set(
          riderRef.collection("earnings_aggregates").doc(key),
          {
            periodType,
            totalLkr: FieldValue.increment(netEarningLkr),
            tripCount: FieldValue.increment(1),
            updatedAt: FieldValue.serverTimestamp(),
          },
          {merge: true},
        );
      }

      if (cashEntry == null) {
        return null;
      }
      return stageCashEntry(tx, {
        riderRef,
        riderData: riderSnap?.data(),
        entryId: `ride_${tripId}`,
        type: "ride_cash",
        entry: cashEntry,
        title: pickupLabel,
        subtitle: String(after.vehicleType ?? tripId),
        tripId,
        maxCashInHandLkr: maxRiderCashInHandLkr,
      });
    });

    logger.info("Recorded rider ride earning", {
      riderId,
      tripId,
      fareLkr,
      commissionLkr,
      cashCollectedLkr: cashEntry?.cashLkr ?? 0,
    });

    if (outcome?.holdActivated) {
      await notifyCashHoldStarted({
        riderId,
        cashInHandLkr: outcome.counters.cashInHandLkr,
        owedLkr: outcome.counters.cashOwedToAdminLkr,
      });
    }
  },
);

/**
 * Server-validated withdrawal request. Verifies the rider is approved and has
 * sufficient balance, then atomically deducts the wallet and creates the
 * pending payout + ledger entry. Client rules forbid writing these docs
 * directly, so balance can no longer be bypassed.
 */
export const requestRiderWithdrawal = onCall(
  {region: REGION},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in to withdraw.");
    }
    const riderId = request.auth.uid;
    const amount = Math.round(Number(request.data?.amountLkr ?? 0));
    const method = String(request.data?.payoutMethod ?? "").trim().toLowerCase();
    const account = String(request.data?.payoutAccount ?? "").trim();
    const note = String(request.data?.note ?? "").trim().slice(0, 500);

    if (!Number.isFinite(amount) || amount < MIN_WITHDRAWAL_LKR) {
      throw new HttpsError(
        "invalid-argument",
        `Minimum withdrawal is Rs. ${MIN_WITHDRAWAL_LKR}.`,
      );
    }
    if (amount > MAX_WITHDRAWAL_LKR) {
      throw new HttpsError(
        "invalid-argument",
        `Maximum withdrawal is Rs. ${MAX_WITHDRAWAL_LKR}.`,
      );
    }
    if (method !== "bank" && method !== "mobile") {
      throw new HttpsError("invalid-argument", "Choose a valid payout method.");
    }
    if (account.length < 4 || account.length > 64) {
      throw new HttpsError("invalid-argument", "Enter valid payout details.");
    }

    const db = getFirestore();
    const riderRef = db.collection("riders").doc(riderId);
    const riderSnap = await riderRef.get();
    const status = String(riderSnap.data()?.status ?? "").trim().toLowerCase();
    if (status !== "approved" && status !== "active") {
      throw new HttpsError(
        "permission-denied",
        "Your account is not approved for payouts.",
      );
    }

    const walletRef = riderRef.collection("wallet").doc("summary");
    const withdrawalRef = riderRef.collection("withdrawals").doc();
    const txnRef = riderRef.collection("transactions").doc(
      `withdrawal_${withdrawalRef.id}`,
    );

    await db.runTransaction(async (tx) => {
      const walletSnap = await tx.get(walletRef);
      const w = walletSnap.data() ?? {};
      const balance = Number(w.balanceLkr ?? 0);
      if (amount > balance) {
        throw new HttpsError("failed-precondition", "Insufficient balance.");
      }

      tx.set(withdrawalRef, {
        riderId,
        amountLkr: amount,
        status: "pending",
        payoutMethod: method,
        payoutAccount: account,
        ledgerTxnId: txnRef.id,
        ...(note ? {note} : {}),
        createdAt: FieldValue.serverTimestamp(),
      });
      tx.set(txnRef, {
        type: "withdrawal",
        status: "pending",
        amountLkr: -amount,
        withdrawalId: withdrawalRef.id,
        title: "Withdrawal request",
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

    return {withdrawalId: withdrawalRef.id, status: "pending"};
  },
);

export type WalletNums = {
  balanceLkr: number;
  pendingWithdrawalLkr: number;
  lifetimeEarnedLkr: number;
  lifetimeWithdrawnLkr: number;
};

export type WithdrawalSettleAction = "paid" | "rejected";

/**
 * Pure wallet math for payout settlement. Callables wrap this in a
 * Firestore transaction so reject restores available balance and paid
 * moves pending into lifetime withdrawn.
 */
export function applyWithdrawalSettlement(args: {
  action: WithdrawalSettleAction;
  status: string;
  amountLkr: number;
  wallet: WalletNums;
}): {
  alreadyDone: boolean;
  nextStatus: "paid" | "rejected";
  ledgerStatus: "completed" | "cancelled";
  wallet: WalletNums;
} {
  const status = String(args.status ?? "").trim().toLowerCase();
  const amount = Math.round(Number(args.amountLkr));
  if (!Number.isFinite(amount) || amount <= 0) {
    throw Object.assign(new Error("Invalid withdrawal amount."), {
      code: "invalid-argument",
    });
  }

  if (args.action === "paid") {
    if (status === "paid") {
      return {
        alreadyDone: true,
        nextStatus: "paid",
        ledgerStatus: "completed",
        wallet: args.wallet,
      };
    }
    if (status !== "pending" && status !== "approved") {
      throw Object.assign(
        new Error(`Cannot mark paid from "${status || "none"}".`),
        {code: "failed-precondition"},
      );
    }
    return {
      alreadyDone: false,
      nextStatus: "paid",
      ledgerStatus: "completed",
      wallet: {
        ...args.wallet,
        pendingWithdrawalLkr: Math.max(0, args.wallet.pendingWithdrawalLkr - amount),
        lifetimeWithdrawnLkr: args.wallet.lifetimeWithdrawnLkr + amount,
      },
    };
  }

  if (status === "rejected") {
    return {
      alreadyDone: true,
      nextStatus: "rejected",
      ledgerStatus: "cancelled",
      wallet: args.wallet,
    };
  }
  if (status !== "pending" && status !== "approved") {
    throw Object.assign(
      new Error(`Cannot reject from "${status || "none"}".`),
      {code: "failed-precondition"},
    );
  }
  return {
    alreadyDone: false,
    nextStatus: "rejected",
    ledgerStatus: "cancelled",
    wallet: {
      ...args.wallet,
      balanceLkr: args.wallet.balanceLkr + amount,
      pendingWithdrawalLkr: Math.max(0, args.wallet.pendingWithdrawalLkr - amount),
    },
  };
}

function toHttpsError(e: unknown): never {
  const code = (e as {code?: string}).code;
  const message = e instanceof Error ? e.message : "Could not settle withdrawal.";
  if (code === "invalid-argument" || code === "failed-precondition") {
    throw new HttpsError(code, message);
  }
  throw new HttpsError("internal", message);
}

/**
 * Admin marks a rider withdrawal paid (cash left the platform) or rejected
 * (restore available balance). Idempotent for the same terminal status.
 */
export const adminSettleRiderWithdrawal = onCall(
  {region: REGION},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in as admin.");
    }
    await assertAdmin(request.auth.uid);

    const riderId = String(request.data?.riderId ?? "").trim();
    const withdrawalId = String(request.data?.withdrawalId ?? "").trim();
    const actionRaw = String(request.data?.action ?? "").trim().toLowerCase();
    const action: WithdrawalSettleAction | "" =
      actionRaw === "paid" || actionRaw === "rejected" ? actionRaw : "";

    if (!riderId || !withdrawalId || !action) {
      throw new HttpsError(
        "invalid-argument",
        "riderId, withdrawalId, and action (paid|rejected) are required.",
      );
    }

    const db = getFirestore();
    const riderRef = db.collection("riders").doc(riderId);
    const withdrawalRef = riderRef.collection("withdrawals").doc(withdrawalId);
    const walletRef = riderRef.collection("wallet").doc("summary");
    const txns = riderRef.collection("transactions");

    try {
      const result = await db.runTransaction(async (tx) => {
        const [wdSnap, walletSnap] = await Promise.all([
          tx.get(withdrawalRef),
          tx.get(walletRef),
        ]);
        if (!wdSnap.exists) {
          throw new HttpsError("not-found", "Withdrawal not found.");
        }
        const wd = wdSnap.data() ?? {};
        const amount = Math.round(Number(wd.amountLkr ?? 0));
        const w = walletSnap.data() ?? {};
        const ledgerTxnId =
          String(wd.ledgerTxnId ?? "").trim() || `withdrawal_${withdrawalId}`;
        const ledgerRef = txns.doc(ledgerTxnId);
        const ledgerSnap = await tx.get(ledgerRef);

        const settlement = applyWithdrawalSettlement({
          action,
          status: String(wd.status ?? ""),
          amountLkr: amount,
          wallet: {
            balanceLkr: Number(w.balanceLkr ?? 0),
            pendingWithdrawalLkr: Number(w.pendingWithdrawalLkr ?? 0),
            lifetimeEarnedLkr: Number(w.lifetimeEarnedLkr ?? 0),
            lifetimeWithdrawnLkr: Number(w.lifetimeWithdrawnLkr ?? 0),
          },
        });

        if (settlement.alreadyDone) {
          return {
            alreadyDone: true,
            status: settlement.nextStatus,
            amountLkr: amount,
          };
        }

        tx.update(withdrawalRef, {
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
          {
            ...settlement.wallet,
            updatedAt: FieldValue.serverTimestamp(),
          },
          {merge: true},
        );
        return {
          alreadyDone: false,
          status: settlement.nextStatus,
          amountLkr: amount,
        };
      });
      if (!result.alreadyDone) {
        await notifyRiderWithdrawalSettled({
          riderId,
          withdrawalId,
          action,
          amountLkr: result.amountLkr,
        });
      }

      return {riderId, withdrawalId, ...result};
    } catch (e) {
      if (e instanceof HttpsError) {
        throw e;
      }
      toHttpsError(e);
    }
  },
);
