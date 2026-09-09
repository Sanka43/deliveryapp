import {FieldValue, getFirestore, Timestamp} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import {computeServiceChargeLkr} from "./serviceCharge";

export type CouponDiscountType = "flat" | "percent";

export interface CouponDoc {
  code: string;
  discountType: CouponDiscountType;
  value: number;
  active: boolean;
  minSubtotalLkr?: number;
  maxDiscountLkr?: number;
  expiresAt?: Timestamp;
  usedCount?: number;
  maxUses?: number;
  /** Caps how many times a single customer may redeem this coupon. */
  perCustomerLimit?: number;
}

export function normalizeCouponCode(raw: string): string {
  return raw.trim().toUpperCase();
}

// A popular coupon code applied by many concurrent orders used to increment
// a single `usedCount` field on the coupon doc itself — a hot document, same
// class of problem as the order tracking-number sequence. Usage is instead
// spread across shard sub-documents; `coupon.usedCount` is no longer written
// and is only an artifact of older data.
const COUPON_USAGE_SHARDS = 20;

function randomCouponUsageShardRef(
  couponRef: FirebaseFirestore.DocumentReference,
): FirebaseFirestore.DocumentReference {
  const shardId = Math.floor(Math.random() * COUPON_USAGE_SHARDS);
  return couponRef.collection("usage_shards").doc(String(shardId));
}

/** Sums usage shards for an accurate count — only needed when a coupon has
 * a `maxUses` limit to enforce; skip this read otherwise. */
export async function sumCouponUsageShards(
  couponRef: FirebaseFirestore.DocumentReference,
  tx?: FirebaseFirestore.Transaction,
): Promise<number> {
  const query = couponRef.collection("usage_shards");
  const snap = tx ? await tx.get(query) : await query.get();
  return snap.docs.reduce((sum, d) => sum + Number(d.data().count ?? 0), 0);
}

/** Call inside a transaction, after all of that transaction's reads. */
export function incrementCouponUsageTx(
  tx: FirebaseFirestore.Transaction,
  couponRef: FirebaseFirestore.DocumentReference,
): void {
  tx.set(
    randomCouponUsageShardRef(couponRef),
    {count: FieldValue.increment(1)},
    {merge: true},
  );
}

/** Standalone (non-transactional) version, for callers outside a transaction. */
export async function incrementCouponUsage(
  couponRef: FirebaseFirestore.DocumentReference,
): Promise<void> {
  await randomCouponUsageShardRef(couponRef).set(
    {count: FieldValue.increment(1)},
    {merge: true},
  );
}

/**
 * Per-customer redemption count for a coupon, keyed by uid — a single small
 * doc (not sharded like `usage_shards`) since at most one customer writes it
 * at a time, so it can't become a hot document the way a shared counter can.
 */
function customerCouponUsageRef(
  couponRef: FirebaseFirestore.DocumentReference,
  uid: string,
): FirebaseFirestore.DocumentReference {
  return couponRef.collection("customer_usage").doc(uid);
}

export async function getCustomerCouponUsageCount(
  couponRef: FirebaseFirestore.DocumentReference,
  uid: string,
  tx?: FirebaseFirestore.Transaction,
): Promise<number> {
  const ref = customerCouponUsageRef(couponRef, uid);
  const snap = tx ? await tx.get(ref) : await ref.get();
  return Number(snap.data()?.count ?? 0);
}

/** Call inside a transaction, after all of that transaction's reads. */
export function incrementCustomerCouponUsageTx(
  tx: FirebaseFirestore.Transaction,
  couponRef: FirebaseFirestore.DocumentReference,
  uid: string,
): void {
  tx.set(
    customerCouponUsageRef(couponRef, uid),
    {count: FieldValue.increment(1)},
    {merge: true},
  );
}

/** Standalone (non-transactional) version, for callers outside a transaction. */
export async function incrementCustomerCouponUsage(
  couponRef: FirebaseFirestore.DocumentReference,
  uid: string,
): Promise<void> {
  await customerCouponUsageRef(couponRef, uid).set(
    {count: FieldValue.increment(1)},
    {merge: true},
  );
}

export function computeDiscountLkr(
  coupon: CouponDoc,
  subtotalLkr: number,
): number {
  if (!coupon.active) {
    return 0;
  }
  if (subtotalLkr <= 0) {
    return 0;
  }
  if (
    coupon.minSubtotalLkr != null &&
    subtotalLkr < coupon.minSubtotalLkr
  ) {
    return 0;
  }
  if (coupon.expiresAt != null && coupon.expiresAt.toMillis() < Date.now()) {
    return 0;
  }
  if (
    coupon.maxUses != null &&
    (coupon.usedCount ?? 0) >= coupon.maxUses
  ) {
    return 0;
  }

  let discount = 0;
  if (coupon.discountType === "flat") {
    discount = Math.min(Math.floor(coupon.value), subtotalLkr);
  } else {
    discount = Math.floor((subtotalLkr * coupon.value) / 100);
    if (coupon.maxDiscountLkr != null) {
      discount = Math.min(discount, coupon.maxDiscountLkr);
    }
  }
  return Math.max(0, Math.min(discount, subtotalLkr));
}

function couponRefFor(code: string): FirebaseFirestore.DocumentReference {
  return getFirestore().collection("coupons").doc(code);
}

async function loadCoupon(code: string): Promise<CouponDoc | null> {
  const snap = await couponRefFor(code).get();
  if (!snap.exists) {
    return null;
  }
  return snap.data() as CouponDoc;
}

/**
 * Checks the coupon's global (`maxUses`) and per-customer (`perCustomerLimit`)
 * redemption caps. Shared by the customer-facing preview (`validateCoupon`)
 * and the order-placement path (`placeOrder.ts`) so both enforce the same
 * limits instead of drifting apart.
 */
export async function checkCouponUsageLimits(
  coupon: CouponDoc,
  couponRef: FirebaseFirestore.DocumentReference,
  uid: string,
  tx?: FirebaseFirestore.Transaction,
): Promise<{ok: true} | {ok: false; error: string}> {
  if (coupon.maxUses != null) {
    const usedCount = await sumCouponUsageShards(couponRef, tx);
    if (usedCount >= coupon.maxUses) {
      return {ok: false, error: "Coupon usage limit reached."};
    }
  }
  if (coupon.perCustomerLimit != null) {
    const customerUsed = await getCustomerCouponUsageCount(couponRef, uid, tx);
    if (customerUsed >= coupon.perCustomerLimit) {
      return {ok: false, error: "You have already used this coupon."};
    }
  }
  return {ok: true};
}

export const validateCoupon = onCall(
  {region: "asia-south1"},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in to apply a coupon.");
    }

    const code = normalizeCouponCode(String(request.data?.code ?? ""));
    const subtotalLkr = Number(request.data?.subtotalLkr ?? 0);
    if (!code) {
      throw new HttpsError("invalid-argument", "Coupon code is required.");
    }
    if (!Number.isFinite(subtotalLkr) || subtotalLkr < 0) {
      throw new HttpsError("invalid-argument", "Invalid cart subtotal.");
    }

    const coupon = await loadCoupon(code);
    if (!coupon) {
      return {valid: false, error: "Coupon not found."};
    }

    const discountLkr = computeDiscountLkr(coupon, Math.floor(subtotalLkr));
    if (discountLkr <= 0) {
      return {
        valid: false,
        error: "This coupon cannot be applied to your cart.",
      };
    }

    const usageCheck = await checkCouponUsageLimits(
      coupon,
      couponRefFor(code),
      request.auth.uid,
    );
    if (!usageCheck.ok) {
      return {valid: false, error: usageCheck.error};
    }

    return {
      valid: true,
      code,
      discountType: coupon.discountType,
      value: coupon.value,
      discountLkr,
    };
  },
);

/** Re-validates coupon on order create and fixes discount/total if needed. */
export const onOrderCreatedValidateCoupon = onDocumentCreated(
  {document: "orders/{orderId}", region: "asia-south1"},
  async (event) => {
    const data = event.data?.data();
    if (!data) {
      return;
    }

    const rawCode = String(data.couponCode ?? "").trim();
    // Orders created by placeCashOnDeliveryOrder already validated + incremented.
    if (data.serverPlaced === true) {
      return;
    }
    if (!rawCode) {
      if (Number(data.discount ?? 0) !== 0) {
        logger.warn("Order has discount without couponCode", {
          orderId: event.params.orderId,
        });
      }
      return;
    }

    const code = normalizeCouponCode(rawCode);
    const subtotal = Number(data.subtotal ?? 0);
    const deliveryFee = Number(data.deliveryFee ?? 0);
    const customerId = String(data.customerId ?? "").trim();
    const couponRef = couponRefFor(code);
    const coupon = await loadCoupon(code);

    let expectedDiscount = coupon ? computeDiscountLkr(coupon, subtotal) : 0;
    if (expectedDiscount > 0 && coupon && customerId) {
      const usageCheck = await checkCouponUsageLimits(coupon, couponRef, customerId);
      if (!usageCheck.ok) {
        expectedDiscount = 0;
      }
    }
    const statedDiscount = Number(data.discount ?? 0);
    const expectedServiceCharge = computeServiceChargeLkr(subtotal);
    const statedServiceCharge = Number(data.serviceCharge ?? 0);
    const expectedTotal = Math.max(
      0,
      subtotal - expectedDiscount + deliveryFee + expectedServiceCharge,
    );

    const patch: Record<string, unknown> = {};
    if (statedDiscount !== expectedDiscount) {
      patch.discount = expectedDiscount;
    }
    if (statedServiceCharge !== expectedServiceCharge) {
      patch.serviceCharge = expectedServiceCharge;
    }
    if (Number(data.total ?? 0) !== expectedTotal) {
      patch.total = expectedTotal;
    }
    if (expectedDiscount <= 0) {
      patch.couponCode = FieldValue.delete();
      patch.couponRejected = true;
    } else {
      patch.couponVerified = true;
      await incrementCouponUsage(couponRef);
      if (customerId) {
        await incrementCustomerCouponUsage(couponRef, customerId);
      }
    }

    if (Object.keys(patch).length > 0) {
      await event.data!.ref.update(patch);
      logger.info("Order coupon adjusted", {
        orderId: event.params.orderId,
        code,
        expectedDiscount,
      });
    }
  },
);
