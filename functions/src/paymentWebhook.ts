import {createHmac, timingSafeEqual} from "crypto";
import {getFirestore, FieldValue} from "firebase-admin/firestore";
import {HttpsError, onRequest} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import * as logger from "firebase-functions/logger";
import {markTripPaidAndOpen} from "./rideTrips";
import {markExistingOrderPaidOnline, markOrderPaidAndPlace} from "./placeOrder";

const paymentWebhookSecret = defineSecret("PAYMENT_WEBHOOK_SECRET");

function verifySignature(
  rawBody: Buffer,
  signatureHeader: string | undefined,
  secret: string,
): boolean {
  if (!signatureHeader || !secret) {
    return false;
  }
  const expected = createHmac("sha256", secret).update(rawBody).digest("hex");
  const provided = signatureHeader.replace(/^sha256=/, "").trim();
  try {
    return timingSafeEqual(
      Buffer.from(expected, "utf8"),
      Buffer.from(provided, "utf8"),
    );
  } catch {
    return false;
  }
}

/**
 * Generic payment webhook endpoint.
 * Requires Secret Manager secret PAYMENT_WEBHOOK_SECRET.
 *
 * Expected JSON body:
 * { orderId?, tripId?, paymentStatus: "paid"|"failed"|"refunded"|"pending", provider?, transactionId? }
 */
export const paymentWebhook = onRequest(
  {region: "asia-south1", cors: false, secrets: [paymentWebhookSecret]},
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method not allowed");
      return;
    }

    const secret = paymentWebhookSecret.value().trim();
    if (!secret) {
      logger.error("paymentWebhook: PAYMENT_WEBHOOK_SECRET is not configured");
      res.status(500).send("Payment webhook not configured");
      return;
    }

    const rawBody = Buffer.isBuffer(req.rawBody)
      ? req.rawBody
      : Buffer.from(JSON.stringify(req.body ?? {}));
    const signature =
      (req.headers["x-mnd-signature"] as string | undefined) ??
      (req.headers["x-hub-signature-256"] as string | undefined);

    if (!verifySignature(rawBody, signature, secret)) {
      logger.warn("paymentWebhook: invalid signature");
      res.status(401).send("Invalid signature");
      return;
    }

    const body = req.body as Record<string, unknown>;
    const orderId = String(body.orderId ?? "").trim();
    const tripId = String(body.tripId ?? "").trim();
    const paymentStatus = String(body.paymentStatus ?? "").trim().toLowerCase();
    const provider = String(body.provider ?? "unknown").trim();
    const transactionId = String(body.transactionId ?? "").trim();

    if ((!orderId && !tripId) || !paymentStatus) {
      res.status(400).send("orderId or tripId, and paymentStatus are required");
      return;
    }

    if (!["paid", "failed", "refunded", "pending"].includes(paymentStatus)) {
      res.status(400).send("Unsupported paymentStatus");
      return;
    }

    if (tripId) {
      if (paymentStatus === "paid") {
        try {
          const bodyAmountRaw =
            body.amount ?? body.paidAmount ?? body.payhere_amount;
          const bodyAmount =
            bodyAmountRaw == null || bodyAmountRaw === ""
              ? undefined
              : Number(bodyAmountRaw);
          const bodyCurrency = String(
            body.currency ?? body.payhere_currency ?? "LKR",
          )
            .trim()
            .toUpperCase();
          await markTripPaidAndOpen(
            tripId,
            provider,
            transactionId || undefined,
            bodyAmount,
            bodyCurrency,
          );
        } catch (e) {
          logger.error("paymentWebhook trip paid failed", e);
          res.status(404).send("Trip not found or invalid state");
          return;
        }
      } else {
        const tripRef = getFirestore().collection("trips").doc(tripId);
        const tripSnap = await tripRef.get();
        if (!tripSnap.exists) {
          res.status(404).send("Trip not found");
          return;
        }
        await tripRef.update({
          paymentStatus,
          paymentProvider: provider,
          paymentUpdatedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
          ...(transactionId ? {paymentTransactionId: transactionId} : {}),
        });
      }

      const tripSnap = await getFirestore().collection("trips").doc(tripId).get();
      const customerId = String(tripSnap.data()?.customerId ?? "");
      if (customerId) {
        await getFirestore().collection("notifications").add({
          userId: customerId,
          tripId,
          type: "payment",
          title:
            paymentStatus === "paid"
              ? "Payment received"
              : paymentStatus === "failed"
                ? "Payment failed"
                : "Payment update",
          body:
            paymentStatus === "paid"
              ? "Your ride payment was successful."
              : paymentStatus === "failed"
                ? "Payment could not be completed. Try again or use cash."
                : `Payment status: ${paymentStatus}`,
          read: false,
          createdAt: FieldValue.serverTimestamp(),
        });
      }

      logger.info("paymentWebhook processed trip", {tripId, paymentStatus, provider});
      res.status(200).json({ok: true, tripId, paymentStatus});
      return;
    }

    const orderRef = getFirestore().collection("orders").doc(orderId);
    const bodyAmountRaw = body.amount ?? body.paidAmount ?? body.payhere_amount;
    const bodyAmount =
      bodyAmountRaw == null || bodyAmountRaw === ""
        ? undefined
        : Number(bodyAmountRaw);
    const bodyCurrency = String(body.currency ?? body.payhere_currency ?? "LKR")
      .trim()
      .toUpperCase();

    let customerId = "";
    let skipNotification = false;
    try {
      const orderSnap = await orderRef.get();
      if (!orderSnap.exists) {
        res.status(404).send("Order not found");
        return;
      }
      const data = orderSnap.data()!;
      customerId = String(data.customerId ?? "");
      const previousStatus = String(data.paymentStatus ?? "").trim().toLowerCase();

      if (
        paymentStatus === "paid" &&
        previousStatus === "paid" &&
        (!transactionId ||
          String(data.paymentTransactionId ?? "") === transactionId)
      ) {
        skipNotification = true;
      } else if (paymentStatus === "paid") {
        // Delegate to the same helpers PayHere's own notify handler uses so
        // this webhook actually advances a draft order to `placed` (and
        // reserves any coupon use) instead of only patching paymentStatus —
        // previously a "paid" webhook could leave an order stuck forever in
        // `draft_payment`, invisible to the vendor and to the customer.
        const orderStatus = String(data.status ?? "").trim();
        const orderPaymentMethod = String(data.paymentMethod ?? "").trim();
        const orderPaymentStatus = String(data.paymentStatus ?? "").trim();
        if (orderStatus === "draft_payment") {
          await markOrderPaidAndPlace(
            orderId,
            provider,
            transactionId || undefined,
            bodyAmount,
            bodyCurrency,
          );
        } else if (
          orderPaymentMethod === "cashOnDelivery" &&
          orderPaymentStatus !== "paid"
        ) {
          await markExistingOrderPaidOnline(
            orderId,
            transactionId || undefined,
            bodyAmount,
            bodyCurrency,
          );
        } else {
          await orderRef.update({
            paymentStatus,
            paymentProvider: provider,
            paymentUpdatedAt: FieldValue.serverTimestamp(),
            paidAt: FieldValue.serverTimestamp(),
            ...(transactionId ? {paymentTransactionId: transactionId} : {}),
          });
        }
      } else {
        await orderRef.update({
          paymentStatus,
          paymentProvider: provider,
          paymentUpdatedAt: FieldValue.serverTimestamp(),
          ...(transactionId ? {paymentTransactionId: transactionId} : {}),
        });
      }
    } catch (e) {
      const code = e instanceof HttpsError ? e.code : undefined;
      if (code === "not-found") {
        res.status(404).send("Order not found");
        return;
      }
      if (code === "failed-precondition") {
        logger.warn("paymentWebhook order amount rejected", {
          orderId,
          bodyAmount,
          bodyCurrency,
          reason: e instanceof Error ? e.message : String(e),
        });
        res.status(400).send("Payment amount does not match order total");
        return;
      }
      logger.error("paymentWebhook order update failed", e);
      res.status(500).send("Order payment update failed");
      return;
    }

    if (customerId && !skipNotification) {
      await getFirestore().collection("notifications").add({
        userId: customerId,
        orderId,
        type: "payment",
        title:
          paymentStatus === "paid"
            ? "Payment received"
            : paymentStatus === "failed"
              ? "Payment failed"
              : "Payment update",
        body:
          paymentStatus === "paid"
            ? "Your card payment was successful."
            : paymentStatus === "failed"
              ? "Payment could not be completed. Try again or use cash."
              : `Payment status: ${paymentStatus}`,
        read: false,
        createdAt: FieldValue.serverTimestamp(),
      });
    }

    logger.info("paymentWebhook processed", {orderId, paymentStatus, provider});
    res.status(200).json({ok: true, orderId, paymentStatus});
  },
);
