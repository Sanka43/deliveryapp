import {createHmac, timingSafeEqual} from "crypto";
import {getFirestore, FieldValue} from "firebase-admin/firestore";
import {onRequest} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

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
 * Configure PAYMENT_WEBHOOK_SECRET in Firebase Functions params / .env.
 *
 * Expected JSON body:
 * { orderId, paymentStatus: "paid"|"failed"|"refunded", provider?, transactionId? }
 */
export const paymentWebhook = onRequest(
  {region: "asia-south1", cors: false},
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method not allowed");
      return;
    }

    const secret = process.env.PAYMENT_WEBHOOK_SECRET ?? "";
    const rawBody = Buffer.isBuffer(req.rawBody)
      ? req.rawBody
      : Buffer.from(JSON.stringify(req.body ?? {}));
    const signature =
      (req.headers["x-mnd-signature"] as string | undefined) ??
      (req.headers["x-hub-signature-256"] as string | undefined);

    if (secret && !verifySignature(rawBody, signature, secret)) {
      logger.warn("paymentWebhook: invalid signature");
      res.status(401).send("Invalid signature");
      return;
    }

    const body = req.body as Record<string, unknown>;
    const orderId = String(body.orderId ?? "").trim();
    const paymentStatus = String(body.paymentStatus ?? "").trim().toLowerCase();
    const provider = String(body.provider ?? "unknown").trim();
    const transactionId = String(body.transactionId ?? "").trim();

    if (!orderId || !paymentStatus) {
      res.status(400).send("orderId and paymentStatus are required");
      return;
    }

    if (!["paid", "failed", "refunded", "pending"].includes(paymentStatus)) {
      res.status(400).send("Unsupported paymentStatus");
      return;
    }

    const orderRef = getFirestore().collection("orders").doc(orderId);
    const orderSnap = await orderRef.get();
    if (!orderSnap.exists) {
      res.status(404).send("Order not found");
      return;
    }

    const patch: Record<string, unknown> = {
      paymentStatus,
      paymentProvider: provider,
      paymentUpdatedAt: FieldValue.serverTimestamp(),
    };
    if (transactionId) {
      patch.paymentTransactionId = transactionId;
    }
    if (paymentStatus === "paid") {
      patch.paidAt = FieldValue.serverTimestamp();
    }

    await orderRef.update(patch);

    const customerId = String(orderSnap.data()?.customerId ?? "");
    if (customerId) {
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
