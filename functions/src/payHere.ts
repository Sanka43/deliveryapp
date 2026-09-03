import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {onRequest} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {payHereCheckoutHash, payHereConfig, payHereNotifyHash} from "./rideFare";
import {markTripPaidAfterCompletion, markTripPaidAndOpen} from "./rideTrips";
import {
  ELIGIBLE_STATUSES_FOR_LATE_PAYHERE,
  markExistingOrderPaidOnline,
  markOrderPaidAndPlace,
} from "./placeOrder";

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

/**
 * Server-hosted, self-submitting PayHere checkout form for a draft order or
 * ride trip. Every caller (mnd.lk web, and every mobile app's in-app
 * WebView) loads this same Cloud Functions URL, so the POST to PayHere
 * always carries this one domain's Origin/Referer. That lets a single
 * PayHere "Domain" integration (instead of one per calling app) authorize
 * checkout for all of them.
 */
export const payHereCheckoutPage = onRequest(
  {region: "asia-south1", cors: false},
  async (req, res) => {
    const type = String(req.query.type ?? "").trim();
    const id = String(req.query.id ?? "").trim();
    if ((type !== "order" && type !== "trip") || !id) {
      res.status(400).send("Invalid checkout link.");
      return;
    }

    const db = getFirestore();
    const snap = await db
      .collection(type === "order" ? "orders" : "trips")
      .doc(id)
      .get();
    if (!snap.exists) {
      res.status(404).send("This checkout link is no longer valid.");
      return;
    }
    const data = snap.data()!;
    // Either the original pre-booking checkout (order or trip still in
    // draft_payment), or a "pay later" checkout for an order paid online
    // after COD placement, or a ride trip paid online after it completed.
    const isDraftPayment =
      data.status === "draft_payment" && data.paymentStatus === "pending";
    const isLateOrderPay =
      type === "order" &&
      ELIGIBLE_STATUSES_FOR_LATE_PAYHERE.has(String(data.status ?? "")) &&
      data.paymentMethod === "cashOnDelivery" &&
      data.paymentStatus !== "paid";
    const isLateTripPay =
      type === "trip" &&
      data.status === "completed" &&
      data.paymentMethod === "payhere" &&
      data.paymentStatus !== "paid";
    if (!isDraftPayment && !isLateOrderPay && !isLateTripPay) {
      res.status(410).send("This checkout has already been used.");
      return;
    }

    const cfg = payHereConfig();
    const amount = Number(
      type === "order" ? data.total : data.estimatedFareLkr,
    ).toFixed(2);
    const currency = "LKR";
    // This page always presents as the mnd.lk origin to PayHere (browser
    // redirect or in-app WebView alike), so it must sign with the Domain
    // secret, not the Mobile App secret.
    const hash = payHereCheckoutHash(
      cfg.merchantId,
      id,
      amount,
      currency,
      cfg.domainMerchantSecret,
    );
    const checkoutUrl = cfg.sandbox
      ? "https://sandbox.payhere.lk/pay/checkout"
      : "https://www.payhere.lk/pay/checkout";
    const firstName = String(data.customerFirstName ?? "Customer");
    const lastName = String(data.customerLastName ?? "MND");
    const email = String(data.customerEmail ?? `${data.customerId}@mnd.local`);

    const fields: Record<string, string> =
      type === "order"
        ? {
          merchant_id: cfg.merchantId,
          return_url: cfg.returnUrl,
          cancel_url: cfg.cancelUrl,
          notify_url: cfg.notifyUrl,
          order_id: id,
          items: `MND Order ${String(data.trackingNumber ?? id)} (${String(data.storeName ?? "")})`,
          currency,
          amount,
          first_name: firstName,
          last_name: lastName,
          email,
          phone: String(data.deliveryAddress?.phone ?? ""),
          address: String(data.deliveryAddress?.line1 ?? "").slice(0, 100),
          city: String(data.deliveryAddress?.city ?? "Sri Lanka"),
          country: "Sri Lanka",
          hash,
        }
        : {
          merchant_id: cfg.merchantId,
          return_url: cfg.returnUrl,
          cancel_url: cfg.cancelUrl,
          notify_url: cfg.notifyUrl,
          order_id: id,
          items: `MND Ride (${String(data.vehicleType ?? "")})`,
          currency,
          amount,
          first_name: firstName,
          last_name: lastName,
          email,
          phone: String(data.contactPhone ?? ""),
          address: "Sri Lanka",
          city: "Sri Lanka",
          country: "Sri Lanka",
          hash,
        };

    const inputs = Object.entries(fields)
      .map(
        ([k, v]) =>
          `<input type="hidden" name="${escapeHtml(k)}" value="${escapeHtml(v)}"/>`,
      )
      .join("\n");
    const html = `<!DOCTYPE html><html><body onload="document.forms[0].submit()">
<form method="POST" action="${escapeHtml(checkoutUrl)}">
${inputs}
</form>
<p>Redirecting to PayHere…</p>
</body></html>`;

    res.set("Content-Type", "text/html; charset=utf-8");
    res.status(200).send(html);
  },
);

/**
 * PayHere server-to-server notify URL (form-urlencoded), shared by both the
 * ride-trip and product-order checkouts. `order_id` is PayHere's generic
 * reference field — it holds either a trip id or an order id depending on
 * which checkout (`createPayHereCheckout` / `createPayHereCheckoutForOrder`)
 * created the payment. status_code 2 = success.
 */
export const payHereNotify = onRequest(
  {region: "asia-south1", cors: false},
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method not allowed");
      return;
    }

    const body = req.body as Record<string, unknown>;
    const merchantId = String(body.merchant_id ?? "").trim();
    const referenceId = String(body.order_id ?? "").trim();
    const payhereAmount = String(body.payhere_amount ?? "").trim();
    const payhereCurrency = String(body.payhere_currency ?? "").trim();
    const statusCode = String(body.status_code ?? "").trim();
    const md5sig = String(body.md5sig ?? "").trim().toUpperCase();
    const paymentId = String(body.payment_id ?? "").trim();
    const authorizationToken = String(body.authorization_token ?? "").trim();

    const expectedMerchant = (process.env.PAYHERE_MERCHANT_ID ?? "").trim();
    const mobileSecret = (process.env.PAYHERE_MERCHANT_SECRET ?? "").trim();
    const domainSecret =
      (process.env.PAYHERE_DOMAIN_MERCHANT_SECRET ?? "").trim() ||
      mobileSecret;
    if (!expectedMerchant || !mobileSecret) {
      logger.error("payHereNotify: merchant secrets missing");
      res.status(500).send("Not configured");
      return;
    }
    if (merchantId !== expectedMerchant) {
      res.status(401).send("Invalid merchant");
      return;
    }

    // A transaction may have been signed with either secret depending on
    // which integration initiated it (native Mobile App SDK vs. the Domain
    // checkout page used by both the web redirect and in-app WebViews) —
    // accept whichever matches rather than assuming one.
    const candidateSecrets = new Set([mobileSecret, domainSecret]);
    const signatureOk = Array.from(candidateSecrets).some(
      (secret) =>
        payHereNotifyHash(
          merchantId,
          referenceId,
          payhereAmount,
          payhereCurrency,
          statusCode,
          secret,
        ) === md5sig,
    );
    if (!signatureOk) {
      logger.warn("payHereNotify: bad signature", {referenceId});
      res.status(401).send("Invalid signature");
      return;
    }

    const db = getFirestore();
    const tripSnap = await db.collection("trips").doc(referenceId).get();
    const isTrip = tripSnap.exists;
    let orderData: Record<string, unknown> | undefined;
    if (!isTrip) {
      const orderSnap = await db.collection("orders").doc(referenceId).get();
      if (!orderSnap.exists) {
        res.status(404).send("Reference not found");
        return;
      }
      orderData = orderSnap.data();
    }

    if (statusCode === "2") {
      try {
        const paidAmount = Number(payhereAmount);
        if (isTrip) {
          const tripStatus = String(tripSnap.data()?.status ?? "");
          const alreadyPaidWithThisTxn =
            String(tripSnap.data()?.paymentStatus ?? "") === "paid" &&
            Boolean(paymentId) &&
            String(tripSnap.data()?.paymentTransactionId ?? "") === paymentId;

          // Only actually mutate — and only notify — when this callback
          // represents new information: a retried webhook call for a
          // payment already recorded under the same transaction id, or a
          // trip in a status we don't act on, should be a silent no-op
          // rather than resending "Payment received" every time.
          let acted = false;
          if (!alreadyPaidWithThisTxn) {
            if (tripStatus === "draft_payment") {
              await markTripPaidAndOpen(
                referenceId,
                "payhere",
                paymentId || undefined,
                paidAmount,
                payhereCurrency || "LKR",
              );
              acted = true;
            } else if (tripStatus === "completed") {
              await markTripPaidAfterCompletion(
                referenceId,
                "payhere",
                paymentId || undefined,
                paidAmount,
                payhereCurrency || "LKR",
              );
              acted = true;
            } else {
              logger.warn("payHereNotify: trip in unexpected status for payment", {
                referenceId,
                tripStatus,
              });
            }
          }
          if (acted) {
            const freshTrip = await db.collection("trips").doc(referenceId).get();
            const customerId = String(freshTrip.data()?.customerId ?? "");
            if (customerId) {
              await db.collection("notifications").add({
                userId: customerId,
                tripId: referenceId,
                type: "payment",
                title: "Payment received",
                body: tripStatus === "draft_payment"
                  ? "Your ride payment was successful. Finding a driver…"
                  : "Your ride payment was successful. Thanks for riding with us!",
                read: false,
                createdAt: FieldValue.serverTimestamp(),
              });
            }
          }
        } else {
          const orderStatus = String(orderData?.status ?? "").trim();
          const orderPaymentMethod = String(orderData?.paymentMethod ?? "").trim();
          const orderPaymentStatus = String(orderData?.paymentStatus ?? "").trim();
          if (orderStatus === "draft_payment") {
            await markOrderPaidAndPlace(
              referenceId,
              "payhere",
              paymentId || undefined,
              paidAmount,
              payhereCurrency || "LKR",
            );
            // Customer "Order placed" + vendor "New order" notifications are
            // sent by onOrderStatusUpdatedNotify's draft_payment -> placed
            // branch, so nothing extra to do here.
          } else if (
            orderPaymentMethod === "cashOnDelivery" &&
            orderPaymentStatus !== "paid"
          ) {
            // A COD order paid online later, via createPayHereCheckoutForExistingOrder.
            await markExistingOrderPaidOnline(
              referenceId,
              paymentId || undefined,
              paidAmount,
              payhereCurrency || "LKR",
            );
          }
        }
      } catch (e) {
        logger.error("payHereNotify: mark paid failed", {e, referenceId, isTrip});
        res.status(500).send("Update failed");
        return;
      }
    } else {
      // status_code 3 = card authorized but not yet captured (the native
      // Mobile SDK "App" checkout lands here instead of a direct 2/success).
      // Treat it as still-pending rather than failed, and hang on to the
      // authorization_token so a future Capture API call can finalize it.
      const nextPaymentStatus =
        statusCode === "-1" || statusCode === "0" || statusCode === "3"
          ? "pending"
          : "failed";
      const patch: Record<string, unknown> = {
        paymentStatus: nextPaymentStatus,
        paymentUpdatedAt: FieldValue.serverTimestamp(),
      };
      if (statusCode === "3" && authorizationToken) {
        patch.paymentAuthorizationToken = authorizationToken;
      }
      const ref = isTrip
        ? db.collection("trips").doc(referenceId)
        : db.collection("orders").doc(referenceId);
      if (isTrip) {
        patch.updatedAt = FieldValue.serverTimestamp();
      }
      await ref.set(patch, {merge: true});
    }

    logger.info("payHereNotify processed", {referenceId, isTrip, statusCode});
    res.status(200).send("OK");
  },
);
