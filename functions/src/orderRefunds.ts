import {
  DocumentData,
  FieldValue,
  getFirestore,
} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {notifyAdmins} from "./orderVendorAcceptReminders";
import {refundPayHerePayment} from "./payHereRefund";

const REGION = "asia-south1";
const MAX_REASON_LEN = 60;
const MAX_DETAIL_LEN = 240;

function normalizedStatus(data: DocumentData): string {
  return String(data.status ?? "").trim().toLowerCase();
}

/** Mirrors `OrderCancellationPolicy.customerMayCancel` in the customer app. */
function customerMayCancel(status: string): boolean {
  return status === "placed" || status === "confirmed";
}

/** Mirrors `orderUnassignedForRiders()` in firestore.rules. */
function orderUnassignedForRiders(data: DocumentData): boolean {
  const assigned = String(data.assignedRiderId ?? data.riderId ?? "").trim();
  return assigned.length === 0;
}

/** Paid online via PayHere (regardless of whether a refund can be automated). */
function isPaidOnline(data: DocumentData): boolean {
  const paymentStatus = String(data.paymentStatus ?? "").trim().toLowerCase();
  const paymentProvider = String(data.paymentProvider ?? "").trim().toLowerCase();
  return paymentStatus === "paid" && paymentProvider === "payhere";
}

/** [isPaidOnline] plus everything a PayHere refund call itself needs. */
function eligibleForOnlineRefund(data: DocumentData): boolean {
  const paymentTransactionId = String(data.paymentTransactionId ?? "").trim();
  const amount = Number(data.total ?? 0);
  return isPaidOnline(data) && paymentTransactionId.length > 0 && amount > 0;
}

function orderTracking(data: DocumentData, orderId: string): string {
  return String(data.trackingNumber ?? "").trim() || orderId;
}

async function notifyCustomer(input: {
  customerId: string;
  orderId: string;
  type: string;
  title: string;
  body: string;
}): Promise<void> {
  const customerId = input.customerId.trim();
  if (!customerId) {
    return;
  }
  await getFirestore().collection("notifications").add({
    userId: customerId,
    orderId: input.orderId,
    type: input.type,
    title: input.title,
    body: input.body,
    read: false,
    createdAt: FieldValue.serverTimestamp(),
  });
}

/**
 * Finalizes a PayHere refund that a caller already staged with
 * `refundRequestStatus: "processing"` — calls the gateway, then writes the
 * outcome. Kept outside any Firestore transaction: the gateway call is slow
 * and must not run inside a transaction's contention-retry loop.
 */
async function finalizeOnlineRefund(input: {
  orderId: string;
  customerId: string;
  amount: number;
  paymentTransactionId: string;
  refundReason: "customer_cancelled" | "customer_requested";
  description: string;
  successBody: string;
}): Promise<{refunded: boolean}> {
  const ref = getFirestore().collection("orders").doc(input.orderId);
  const result = await refundPayHerePayment(
    input.paymentTransactionId,
    input.amount,
    input.description,
  );

  if (result.ok) {
    await ref.update({
      paymentStatus: "refunded",
      refundedAt: FieldValue.serverTimestamp(),
      refundReason: input.refundReason,
      refundReference: result.refundId,
      refundedBy: "customer",
      refundRequestStatus: "completed",
      updatedAt: FieldValue.serverTimestamp(),
    });
    await notifyCustomer({
      customerId: input.customerId,
      orderId: input.orderId,
      type: "payment",
      title: "Payment refunded",
      body: input.successBody,
    });
    return {refunded: true};
  }

  logger.error("Customer-triggered refund failed", {
    orderId: input.orderId,
    error: result.error,
  });
  await ref.update({
    refundFailed: true,
    refundFailedAt: FieldValue.serverTimestamp(),
    refundError: result.error,
    // Fall back to manual review — the customer already knows a refund is
    // owed, so this must not just silently stay "processing" forever.
    refundRequestStatus: "pending_review",
    updatedAt: FieldValue.serverTimestamp(),
  });
  await notifyCustomer({
    customerId: input.customerId,
    orderId: input.orderId,
    type: "payment",
    title: "Refund pending",
    body:
      "We could not process your refund automatically. Our team has " +
      "been notified and will process it shortly.",
  });
  await notifyAdmins({
    title: "Refund failed — needs action",
    body: `Order ${input.orderId}: automatic refund failed — ${result.error}`,
    orderId: input.orderId,
  });
  return {refunded: false};
}

/**
 * Customer cancels their own `placed`/`confirmed` order. Runs server-side
 * (rather than the client writing Firestore directly) so a paid-online order
 * can be refunded automatically in the same step — previously only the
 * vendor-no-response auto-cancel sweep (`orderVendorAcceptReminders.ts`) did
 * this, leaving customer-initiated cancellations with no way to get their
 * money back.
 */
export const cancelOrderByCustomer = onCall({region: REGION}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in to cancel an order.");
  }
  const uid = request.auth.uid;
  const orderId = String(request.data?.orderId ?? "").trim();
  if (!orderId) {
    throw new HttpsError("invalid-argument", "orderId is required.");
  }
  const reasonId = String(request.data?.reasonId ?? "")
    .trim()
    .toLowerCase()
    .slice(0, MAX_REASON_LEN);
  if (!reasonId) {
    throw new HttpsError("invalid-argument", "Choose a cancellation reason.");
  }
  const otherDetail = String(request.data?.otherDetail ?? "")
    .trim()
    .slice(0, MAX_DETAIL_LEN);
  if (reasonId === "other" && !otherDetail) {
    throw new HttpsError("invalid-argument", "Please describe your reason.");
  }

  const ref = getFirestore().collection("orders").doc(orderId);
  const orderData = await getFirestore().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) {
      throw new HttpsError("not-found", "Order not found.");
    }
    const data = snap.data()!;
    if (String(data.customerId ?? "") !== uid) {
      throw new HttpsError("permission-denied", "You cannot cancel this order.");
    }
    const status = normalizedStatus(data);
    if (!customerMayCancel(status) || !orderUnassignedForRiders(data)) {
      throw new HttpsError(
        "failed-precondition",
        "This order can no longer be cancelled.",
      );
    }

    const update: Record<string, unknown> = {
      status: "cancelled",
      cancellationReason: reasonId,
      cancelledAt: FieldValue.serverTimestamp(),
      cancelledBy: "customer",
      updatedAt: FieldValue.serverTimestamp(),
    };
    if (otherDetail) {
      update.cancellationReasonDetail = otherDetail;
    }
    if (isPaidOnline(data)) {
      update.refundRequestedAt = FieldValue.serverTimestamp();
      update.refundRequestedBy = "customer";
      // Missing transaction id is a data-quality edge case (should not
      // happen for a real PayHere payment) — queue it for a person rather
      // than silently cancelling a paid order with no refund at all.
      update.refundRequestStatus = eligibleForOnlineRefund(data) ?
        "processing" :
        "pending_review";
    }
    tx.update(ref, update);
    return data;
  });

  if (!isPaidOnline(orderData)) {
    return {status: "cancelled", outcome: "no_refund_needed"};
  }
  if (!eligibleForOnlineRefund(orderData)) {
    await notifyAdmins({
      title: "Refund needs manual review",
      body: `Order ${orderTracking(orderData, orderId)}: cancelled by customer ` +
        "but is missing payment details needed to auto-refund.",
      orderId,
    });
    return {status: "cancelled", outcome: "pending_review"};
  }

  const {refunded} = await finalizeOnlineRefund({
    orderId,
    customerId: uid,
    amount: Number(orderData.total ?? 0),
    paymentTransactionId: String(orderData.paymentTransactionId ?? ""),
    refundReason: "customer_cancelled",
    description: "Order cancelled by customer",
    successBody: "Your order was cancelled and your payment was refunded.",
  });

  return {status: "cancelled", outcome: refunded ? "refunded" : "pending_review"};
});

type RefundRequestPhase =
  | {outcome: "already_refunded"}
  | {outcome: "already_pending"}
  | {outcome: "auto_refund"; data: DocumentData}
  | {outcome: "pending_review"; data: DocumentData};

/**
 * Customer asks for money back on an order they can no longer cancel from
 * the app — already cancelled by the shop/system, delivered with an issue,
 * and so on. This is the gap the automatic vendor-no-response refund never
 * covered: previously the app gave the customer no way to ask for a refund
 * at all outside that one narrow case.
 *
 * A `cancelled` order that was paid online is refunded immediately, the same
 * as the automatic sweep does. Anything else needs a person to look at it
 * (a delivered order with a quality complaint, a COD order, etc.), so it is
 * queued for admin review instead of guessing.
 */
export const requestOrderRefund = onCall({region: REGION}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in to request a refund.");
  }
  const uid = request.auth.uid;
  const orderId = String(request.data?.orderId ?? "").trim();
  if (!orderId) {
    throw new HttpsError("invalid-argument", "orderId is required.");
  }
  const reason = String(request.data?.reason ?? "").trim().slice(0, MAX_DETAIL_LEN);

  const ref = getFirestore().collection("orders").doc(orderId);
  const phase: RefundRequestPhase = await getFirestore().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) {
      throw new HttpsError("not-found", "Order not found.");
    }
    const data = snap.data()!;
    if (String(data.customerId ?? "") !== uid) {
      throw new HttpsError(
        "permission-denied",
        "You cannot request a refund for this order.",
      );
    }
    const paymentStatus = String(data.paymentStatus ?? "").trim().toLowerCase();
    if (paymentStatus === "refunded") {
      return {outcome: "already_refunded" as const};
    }
    if (paymentStatus !== "paid") {
      throw new HttpsError(
        "failed-precondition",
        "There is no payment to refund for this order.",
      );
    }
    const existingRequest = String(data.refundRequestStatus ?? "").trim().toLowerCase();
    if (existingRequest === "processing" || existingRequest === "pending_review") {
      return {outcome: "already_pending" as const};
    }
    const status = normalizedStatus(data);
    if (customerMayCancel(status)) {
      throw new HttpsError(
        "failed-precondition",
        "Cancel the order to get an automatic refund.",
      );
    }

    const update: Record<string, unknown> = {
      refundRequestedAt: FieldValue.serverTimestamp(),
      refundRequestedBy: "customer",
      updatedAt: FieldValue.serverTimestamp(),
      ...(reason ? {refundRequestReason: reason} : {}),
    };
    if (status === "cancelled" && eligibleForOnlineRefund(data)) {
      tx.update(ref, {...update, refundRequestStatus: "processing"});
      return {outcome: "auto_refund" as const, data};
    }
    tx.update(ref, {...update, refundRequestStatus: "pending_review"});
    return {outcome: "pending_review" as const, data};
  });

  if (phase.outcome === "already_refunded" || phase.outcome === "already_pending") {
    return {outcome: phase.outcome};
  }

  if (phase.outcome === "pending_review") {
    const tracking = orderTracking(phase.data, orderId);
    await Promise.all([
      notifyAdmins({
        title: "Refund requested",
        body: `Order ${tracking}: customer requested a refund.` +
          (reason ? ` "${reason}"` : ""),
        orderId,
      }),
      notifyCustomer({
        customerId: uid,
        orderId,
        type: "payment",
        title: "Refund request received",
        body: "We received your refund request. Our team will review it and get back to you.",
      }),
    ]);
    return {outcome: "pending_review"};
  }

  const {refunded} = await finalizeOnlineRefund({
    orderId,
    customerId: uid,
    amount: Number(phase.data.total ?? 0),
    paymentTransactionId: String(phase.data.paymentTransactionId ?? ""),
    refundReason: "customer_requested",
    description: "Refund requested by customer",
    successBody: "Your refund has been processed to your original payment method.",
  });

  return {outcome: refunded ? "refunded" : "pending_review"};
});
