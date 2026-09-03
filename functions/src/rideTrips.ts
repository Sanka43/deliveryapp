import {FieldValue, getFirestore, Timestamp} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";
import {loadValidQuote, payHereCheckoutHash, payHereConfig} from "./rideFare";

/** How long a ride can sit unclaimed in "searching" before auto-cancelling. */
export const SEARCH_TIMEOUT_MS = 15 * 60 * 1000;

function tripCreatedAtMillis(value: unknown): number | null {
  if (value instanceof Timestamp) {
    return value.toMillis();
  }
  if (value instanceof Date) {
    return value.getTime();
  }
  return null;
}

function requirePhone(raw: unknown): string {
  const phone = String(raw ?? "").trim();
  if (phone.length < 8 || phone.length > 20) {
    throw new HttpsError(
      "invalid-argument",
      "A valid contact phone is required.",
    );
  }
  return phone;
}

export async function markTripPaidAndOpen(
  tripId: string,
  provider: string,
  transactionId?: string,
  paidAmountLkr?: number,
  paidCurrency?: string,
): Promise<void> {
  const ref = getFirestore().collection("trips").doc(tripId);
  await getFirestore().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) {
      throw new HttpsError("not-found", "Trip not found.");
    }
    const data = snap.data()!;
    const status = String(data.status ?? "");
    if (status === "searching" || status === "accepted" || status === "arrived" ||
      status === "in_progress" || status === "completed") {
      return;
    }
    if (status !== "draft_payment") {
      throw new HttpsError(
        "failed-precondition",
        `Trip cannot be paid from status ${status}.`,
      );
    }
    if (paidAmountLkr != null) {
      const expectedFare = Math.floor(Number(data.estimatedFareLkr ?? NaN));
      if (!Number.isFinite(expectedFare)) {
        throw new HttpsError("failed-precondition", "Trip fare is missing.");
      }
      const currency = String(paidCurrency ?? "LKR").trim().toUpperCase();
      if (currency !== "LKR") {
        throw new HttpsError("failed-precondition", "Unsupported payment currency.");
      }
      // Compare to 2 decimal places (PayHere amount strings like "250.00").
      const paidCents = Math.round(Number(paidAmountLkr) * 100);
      const expectedCents = Math.round(expectedFare * 100);
      if (!Number.isFinite(paidCents) || paidCents !== expectedCents) {
        throw new HttpsError(
          "failed-precondition",
          `Paid amount ${paidAmountLkr} does not match trip fare ${expectedFare}.`,
        );
      }
    }
    const patch: Record<string, unknown> = {
      paymentStatus: "paid",
      paymentProvider: provider,
      paymentUpdatedAt: FieldValue.serverTimestamp(),
      paidAt: FieldValue.serverTimestamp(),
      status: "searching",
      openForRiders: true,
      updatedAt: FieldValue.serverTimestamp(),
    };
    if (transactionId) {
      patch.paymentTransactionId = transactionId;
    }
    tx.update(ref, patch);
  });
}

/**
 * Books a trip that starts searching for a driver immediately — used for
 * both cash rides and PayHere rides. Online-pay trips are settled after
 * the trip is completed (see `createPayHereCheckoutForTrip`), not before
 * a driver is even matched, so both payment methods share this same
 * "create + start searching now" path.
 */
export const confirmCashRide = onCall(
  {region: "asia-south1"},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in to book a ride.");
    }
    const quoteId = String(request.data?.quoteId ?? "").trim();
    if (!quoteId) {
      throw new HttpsError("invalid-argument", "quoteId is required.");
    }
    const contactPhone = requirePhone(request.data?.contactPhone);
    const driverNote = String(request.data?.driverNote ?? "").trim().slice(0, 500);
    const paymentMethod =
      String(request.data?.paymentMethod ?? "cash").trim().toLowerCase() ===
      "payhere"
        ? "payhere"
        : "cash";

    const quote = await loadValidQuote(quoteId, request.auth.uid);
    const tripRef = getFirestore().collection("trips").doc();
    const quoteRef = getFirestore().collection("ride_fare_quotes").doc(quoteId);
    await getFirestore().runTransaction(async (tx) => {
      const quoteSnap = await tx.get(quoteRef);
      if (!quoteSnap.exists) {
        throw new HttpsError("not-found", "Fare quote not found.");
      }
      const q = quoteSnap.data()!;
      if (String(q.customerId) !== request.auth!.uid) {
        throw new HttpsError("permission-denied", "This quote is not yours.");
      }
      if (q.usedTripId) {
        throw new HttpsError("failed-precondition", "Fare quote already used.");
      }
      const expiresAt = q.expiresAt as {toMillis?: () => number} | undefined;
      if (!expiresAt?.toMillis || expiresAt.toMillis() < Date.now()) {
        throw new HttpsError("failed-precondition", "Fare quote expired.");
      }
      tx.set(tripRef, {
        customerId: request.auth!.uid,
        contactPhone,
        driverNote,
        pickup: quote.pickup,
        dropoff: quote.dropoff,
        stops: quote.stops,
        vehicleType: quote.vehicleType,
        distanceKm: quote.distanceKm,
        estimatedFareLkr: quote.fareLkr,
        fareQuoteId: quoteId,
        status: "searching",
        openForRiders: true,
        paymentMethod,
        paymentStatus: "pending",
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      tx.update(quoteRef, {
        usedTripId: tripRef.id,
        usedAt: FieldValue.serverTimestamp(),
      });
    });

    return {tripId: tripRef.id, status: "searching"};
  },
);

export const createPayHereCheckout = onCall(
  {region: "asia-south1"},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in to pay for a ride.");
    }
    const quoteId = String(request.data?.quoteId ?? "").trim();
    if (!quoteId) {
      throw new HttpsError("invalid-argument", "quoteId is required.");
    }
    const contactPhone = requirePhone(request.data?.contactPhone);
    const driverNote = String(request.data?.driverNote ?? "").trim().slice(0, 500);
    const firstName = String(request.data?.firstName ?? "Customer").trim().slice(0, 80) || "Customer";
    const lastName = String(request.data?.lastName ?? "MND").trim().slice(0, 80) || "MND";
    const email = String(request.data?.email ?? "").trim();

    const quote = await loadValidQuote(quoteId, request.auth.uid);
    const cfg = payHereConfig();
    const tripRef = getFirestore().collection("trips").doc();
    const tripId = tripRef.id;
    const quoteRef = getFirestore().collection("ride_fare_quotes").doc(quoteId);
    const amount = quote.fareLkr.toFixed(2);
    const currency = "LKR";
    const hash = payHereCheckoutHash(
      cfg.merchantId,
      tripId,
      amount,
      currency,
      cfg.merchantSecret,
    );

    await getFirestore().runTransaction(async (tx) => {
      const quoteSnap = await tx.get(quoteRef);
      if (!quoteSnap.exists) {
        throw new HttpsError("not-found", "Fare quote not found.");
      }
      const q = quoteSnap.data()!;
      if (String(q.customerId) !== request.auth!.uid) {
        throw new HttpsError("permission-denied", "This quote is not yours.");
      }
      if (q.usedTripId) {
        throw new HttpsError("failed-precondition", "Fare quote already used.");
      }
      const expiresAt = q.expiresAt as {toMillis?: () => number} | undefined;
      if (!expiresAt?.toMillis || expiresAt.toMillis() < Date.now()) {
        throw new HttpsError("failed-precondition", "Fare quote expired.");
      }
      tx.set(tripRef, {
        customerId: request.auth!.uid,
        contactPhone,
        driverNote,
        pickup: quote.pickup,
        dropoff: quote.dropoff,
        stops: quote.stops,
        vehicleType: quote.vehicleType,
        distanceKm: quote.distanceKm,
        estimatedFareLkr: quote.fareLkr,
        fareQuoteId: quoteId,
        status: "draft_payment",
        openForRiders: false,
        paymentMethod: "payhere",
        paymentStatus: "pending",
        paymentProvider: "payhere",
        customerFirstName: firstName,
        customerLastName: lastName,
        customerEmail: email || `${request.auth!.uid}@mnd.local`,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      tx.update(quoteRef, {
        usedTripId: tripId,
        usedAt: FieldValue.serverTimestamp(),
      });
    });

    const checkoutUrl = cfg.sandbox
      ? "https://sandbox.payhere.lk/pay/checkout"
      : "https://www.payhere.lk/pay/checkout";

    return {
      tripId,
      checkoutUrl,
      checkoutPageUrl: `${cfg.checkoutPageUrl}?type=trip&id=${encodeURIComponent(tripId)}`,
      fields: {
        merchant_id: cfg.merchantId,
        return_url: cfg.returnUrl,
        cancel_url: cfg.cancelUrl,
        notify_url: cfg.notifyUrl,
        order_id: tripId,
        items: `MND Ride (${quote.vehicleType})`,
        currency,
        amount,
        first_name: firstName,
        last_name: lastName,
        email: email || `${request.auth.uid}@mnd.local`,
        phone: contactPhone,
        address: quote.pickup.label.slice(0, 100),
        city: "Sri Lanka",
        country: "Sri Lanka",
        hash,
      },
    };
  },
);

/**
 * Assigned rider completes a passenger trip. Only flips `status` to
 * "completed" — payment is confirmed separately: cash trips move to "paid"
 * only when the rider explicitly confirms via `confirmCashRidePayment`
 * (they may not have collected the fare yet at the moment of completion);
 * PayHere trips are left `paymentStatus: "pending"` here — the customer pays
 * online afterward via `createPayHereCheckoutForTrip` / `markTripPaidAfterCompletion`.
 */
export const completeCashOrRideTrip = onCall(
  {region: "asia-south1"},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in to complete a trip.");
    }
    const riderUid = request.auth.uid;
    const tripId = String(request.data?.tripId ?? "").trim();
    if (!tripId) {
      throw new HttpsError("invalid-argument", "tripId is required.");
    }

    const tripRef = getFirestore().collection("trips").doc(tripId);

    await getFirestore().runTransaction(async (tx) => {
      const snap = await tx.get(tripRef);
      if (!snap.exists) {
        throw new HttpsError("not-found", "Trip not found.");
      }
      const data = snap.data()!;
      const status = String(data.status ?? "").trim().toLowerCase();
      if (status === "completed") {
        return;
      }
      if (status !== "in_progress") {
        throw new HttpsError(
          "failed-precondition",
          `Trip cannot be completed from status "${status}".`,
        );
      }

      const assigned = String(data.riderId ?? data.assignedRiderId ?? "").trim();
      if (!assigned || assigned !== riderUid) {
        throw new HttpsError(
          "permission-denied",
          "Only the assigned rider can complete this trip.",
        );
      }

      // Every intermediate stop must be visited (currentStopIndex advanced
      // to stops.length via the dedicated stop-advance path) before the
      // final leg can complete — mirrors the Firestore rules guard so a
      // rider can't finish a multi-stop ride mid-route through either path.
      const stops = Array.isArray(data.stops) ? data.stops : [];
      const currentStopIndex = Math.floor(Number(data.currentStopIndex ?? 0));
      if (stops.length > 0 && currentStopIndex < stops.length) {
        throw new HttpsError(
          "failed-precondition",
          "Visit every stop before completing this trip.",
        );
      }

      tx.update(tripRef, {
        status: "completed",
        completedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    return {tripId, status: "completed"};
  },
);

/**
 * Assigned rider confirms they collected cash for an already-`completed`
 * trip. The only place `paymentStatus` advances to "paid" for cash trips —
 * decoupled from `completeCashOrRideTrip` so the rider has an explicit
 * confirmation step instead of payment being assumed at completion time.
 * Idempotent: a no-op if already paid.
 */
export const confirmCashRidePayment = onCall(
  {region: "asia-south1"},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in to confirm payment.");
    }
    const riderUid = request.auth.uid;
    const tripId = String(request.data?.tripId ?? "").trim();
    if (!tripId) {
      throw new HttpsError("invalid-argument", "tripId is required.");
    }

    const tripRef = getFirestore().collection("trips").doc(tripId);

    await getFirestore().runTransaction(async (tx) => {
      const snap = await tx.get(tripRef);
      if (!snap.exists) {
        throw new HttpsError("not-found", "Trip not found.");
      }
      const data = snap.data()!;

      const assigned = String(data.riderId ?? data.assignedRiderId ?? "").trim();
      if (!assigned || assigned !== riderUid) {
        throw new HttpsError(
          "permission-denied",
          "Only the assigned rider can confirm payment for this trip.",
        );
      }

      const status = String(data.status ?? "").trim().toLowerCase();
      if (status !== "completed") {
        throw new HttpsError(
          "failed-precondition",
          `Trip must be completed before confirming payment (current status: "${status}").`,
        );
      }

      const paymentMethod = String(data.paymentMethod ?? "").trim().toLowerCase();
      if (paymentMethod !== "cash") {
        throw new HttpsError(
          "failed-precondition",
          "Only cash trips are confirmed this way.",
        );
      }

      if (String(data.paymentStatus ?? "").trim().toLowerCase() === "paid") {
        return;
      }

      tx.update(tripRef, {
        paymentStatus: "paid",
        paymentProvider: "cash",
        paidAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    return {tripId, paymentStatus: "paid"};
  },
);

/**
 * Confirms online payment for a PayHere trip that is already `completed`
 * (paid at the end of the ride, not before it was searched/matched). Called
 * by `payHereNotify`. Idempotent, mirrors `markExistingOrderPaidOnline`.
 */
export async function markTripPaidAfterCompletion(
  tripId: string,
  provider: string,
  transactionId?: string,
  paidAmountLkr?: number,
  paidCurrency?: string,
): Promise<void> {
  const ref = getFirestore().collection("trips").doc(tripId);
  await getFirestore().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) {
      throw new HttpsError("not-found", "Trip not found.");
    }
    const data = snap.data()!;
    if (
      data.paymentStatus === "paid" &&
      transactionId &&
      data.paymentTransactionId === transactionId
    ) {
      return;
    }
    if (String(data.status ?? "") !== "completed") {
      throw new HttpsError(
        "failed-precondition",
        `Trip is not completed yet (status ${data.status}).`,
      );
    }
    if (paidAmountLkr != null) {
      const expectedFare = Math.floor(Number(data.estimatedFareLkr ?? NaN));
      if (!Number.isFinite(expectedFare)) {
        throw new HttpsError("failed-precondition", "Trip fare is missing.");
      }
      const currency = String(paidCurrency ?? "LKR").trim().toUpperCase();
      if (currency !== "LKR") {
        throw new HttpsError("failed-precondition", "Unsupported payment currency.");
      }
      const paidCents = Math.round(Number(paidAmountLkr) * 100);
      const expectedCents = Math.round(expectedFare * 100);
      if (!Number.isFinite(paidCents) || paidCents !== expectedCents) {
        throw new HttpsError(
          "failed-precondition",
          `Paid amount ${paidAmountLkr} does not match trip fare ${expectedFare}.`,
        );
      }
    }
    const patch: Record<string, unknown> = {
      paymentStatus: "paid",
      paymentProvider: provider,
      paymentUpdatedAt: FieldValue.serverTimestamp(),
      paidAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    };
    if (transactionId) {
      patch.paymentTransactionId = transactionId;
    }
    tx.update(ref, patch);
  });
}

/**
 * Lets a customer pay online (PayHere) for a ride that already completed
 * with `paymentMethod: "payhere"` and is still unpaid. Reuses the trip's
 * existing id/estimated fare — the trip is only marked paid once
 * `payHereNotify` confirms payment via `markTripPaidAfterCompletion`.
 */
export const createPayHereCheckoutForTrip = onCall(
  {region: "asia-south1"},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in to pay for this ride.");
    }
    const uid = request.auth.uid;
    const tripId = String(request.data?.tripId ?? "").trim();
    if (!tripId) {
      throw new HttpsError("invalid-argument", "tripId is required.");
    }

    const db = getFirestore();
    const snap = await db.collection("trips").doc(tripId).get();
    if (!snap.exists) {
      throw new HttpsError("not-found", "Trip not found.");
    }
    const data = snap.data()!;
    if (String(data.customerId ?? "") !== uid) {
      throw new HttpsError(
        "permission-denied",
        "You are not allowed to pay for this trip.",
      );
    }
    if (String(data.paymentMethod ?? "") !== "payhere") {
      throw new HttpsError(
        "failed-precondition",
        "This trip is not set up for online payment.",
      );
    }
    if (data.paymentStatus === "paid") {
      throw new HttpsError("failed-precondition", "This trip is already paid.");
    }
    if (String(data.status ?? "") !== "completed") {
      throw new HttpsError(
        "failed-precondition",
        `Trip cannot be paid online from status "${data.status}".`,
      );
    }

    const fareLkr = Math.floor(Number(data.estimatedFareLkr ?? NaN));
    if (!Number.isFinite(fareLkr)) {
      throw new HttpsError("failed-precondition", "Trip fare is missing.");
    }

    const cfg = payHereConfig();
    const amount = fareLkr.toFixed(2);
    const currency = "LKR";
    const hash = payHereCheckoutHash(
      cfg.merchantId,
      tripId,
      amount,
      currency,
      cfg.merchantSecret,
    );
    const checkoutUrl = cfg.sandbox
      ? "https://sandbox.payhere.lk/pay/checkout"
      : "https://www.payhere.lk/pay/checkout";
    const firstName = String(data.customerFirstName ?? "Customer");
    const lastName = String(data.customerLastName ?? "MND");
    const email = String(data.customerEmail ?? `${uid}@mnd.local`);

    return {
      tripId,
      checkoutUrl,
      checkoutPageUrl: `${cfg.checkoutPageUrl}?type=trip&id=${encodeURIComponent(tripId)}`,
      fields: {
        merchant_id: cfg.merchantId,
        return_url: cfg.returnUrl,
        cancel_url: cfg.cancelUrl,
        notify_url: cfg.notifyUrl,
        order_id: tripId,
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
      },
    };
  },
);

/**
 * Auto-cancels a ride that's sat unclaimed in "searching" too long — no
 * driver ever accepted it — instead of leaving it open forever with no
 * backend backstop (the customer app's own "no drivers nearby" message is
 * client-side pacing only and doesn't touch the trip document). Reuses the
 * existing `openForRiders + status` composite index, so no new index is
 * needed.
 */
export const sweepStaleSearchingTrips = onSchedule(
  {
    schedule: "every 5 minutes",
    timeZone: "Asia/Colombo",
    region: "asia-south1",
    timeoutSeconds: 120,
    memory: "256MiB",
  },
  async () => {
    const db = getFirestore();
    const nowMs = Date.now();
    const snap = await db
      .collection("trips")
      .where("openForRiders", "==", true)
      .where("status", "==", "searching")
      .limit(200)
      .get();

    let cancelled = 0;
    for (const doc of snap.docs) {
      const data = doc.data();
      const createdMs = tripCreatedAtMillis(data.createdAt);
      if (createdMs == null || nowMs - createdMs < SEARCH_TIMEOUT_MS) {
        continue;
      }
      try {
        const didCancel = await db.runTransaction(async (tx) => {
          const fresh = await tx.get(doc.ref);
          const freshData = fresh.data();
          if (!freshData) {
            return false;
          }
          if (
            String(freshData.status ?? "") !== "searching" ||
            freshData.openForRiders !== true
          ) {
            // Claimed or cancelled by something else since the scan.
            return false;
          }
          tx.update(doc.ref, {
            status: "cancelled",
            openForRiders: false,
            cancelledBy: "system",
            cancelReason: "no_driver_found",
            cancelledAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          });
          return true;
        });
        if (!didCancel) {
          continue;
        }
        cancelled += 1;
        const customerId = String(data.customerId ?? "").trim();
        if (customerId) {
          await db.collection("notifications").add({
            userId: customerId,
            tripId: doc.id,
            type: "ride_timeout",
            title: "No drivers found",
            body: "We couldn't find a driver for your ride. Please try requesting again.",
            read: false,
            createdAt: FieldValue.serverTimestamp(),
          });
        }
      } catch (err) {
        logger.error("sweepStaleSearchingTrips: cancel failed", {
          err,
          tripId: doc.id,
        });
      }
    }

    logger.info("Stale searching-trip sweep complete", {
      scanned: snap.size,
      cancelled,
    });
  },
);

