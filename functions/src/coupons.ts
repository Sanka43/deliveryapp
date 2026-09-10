import {FieldValue, getFirestore, Timestamp} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import {computeServiceChargeLkr} from "./serviceCharge";

export type CouponDiscountType = "flat" | "percent";

/** `pending` | `approved` | `rejected` — vendor-submitted coupons only; an
 * admin-created coupon has no `status` at all and is usable immediately
 * (see `couponUsableForVendor`). */
export type CouponApprovalStatus = "pending" | "approved" | "rejected";

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
  /** Set only for a vendor-submitted coupon — scopes it to that one store.
   * Absent for a platform-wide admin coupon. */
  storeId?: string;
  /** Vendor-submitted coupons start `pending`; admin approves/rejects before
   * they can ever discount an order. Absent (admin-created) == usable. */
  status?: CouponApprovalStatus;
  createdBy?: "admin" | "vendor";
}

/**
 * Whether [coupon] may discount an order placed with vendor [vendorId] —
 * separate from [computeDiscountLkr]'s amount math, which doesn't know about
 * store scoping or approval state.
 *
 * - A vendor-submitted coupon (`storeId` set) only ever applies to that
 *   store's own orders, and only once admin has approved it.
 * - A platform-wide admin coupon (no `storeId`) has no `status` field at all
 *   and applies everywhere — unaffected by this check.
 */
export function couponUsableForVendor(coupon: CouponDoc, vendorId: string): boolean {
  if (coupon.status === "pending" || coupon.status === "rejected") {
    return false;
  }
  const storeId = String(coupon.storeId ?? "").trim();
  if (storeId && storeId !== vendorId.trim()) {
    return false;
  }
  return true;
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
    // The cart's single vendor — required to check a vendor-submitted
    // coupon's store scope. Older clients that don't send it simply can't
    // redeem store-scoped coupons; platform-wide (admin) coupons are
    // unaffected either way.
    const storeId = String(request.data?.storeId ?? "").trim();
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
    if (!couponUsableForVendor(coupon, storeId)) {
      return {valid: false, error: "This coupon is not valid for this store."};
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
    const vendorId = String(data.vendorId ?? data.vendorStoreId ?? "").trim();
    const couponRef = couponRefFor(code);
    const coupon = await loadCoupon(code);

    let expectedDiscount =
      coupon && couponUsableForVendor(coupon, vendorId) ?
        computeDiscountLkr(coupon, subtotal) :
        0;
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

const MAX_CODE_LEN = 20;
const MIN_CODE_LEN = 3;
const MAX_FLAT_VALUE_LKR = 100000;
const MAX_PERCENT_VALUE = 70;
const MAX_COUPON_LIFETIME_MS = 365 * 24 * 60 * 60 * 1000;

/**
 * Vendor self-service coupon creation — the gap that previously left coupons
 * 100% admin-driven with no vendor visibility or involvement at all. Coupon
 * discounts already come out of `productCashLkr` (the shop's own cut, see
 * `placeCashOnDeliveryOrder`), so a vendor-submitted coupon is naturally
 * vendor-funded with no extra bookkeeping needed.
 *
 * Starts `pending`: an admin must approve it (mnd_web Coupons page, same
 * approve/reject pattern as vendor-submitted `offers`) before
 * `couponUsableForVendor` will ever let it discount an order — a vendor
 * cannot make their own promo live unsupervised.
 */
export const requestVendorCoupon = onCall({region: "asia-south1"}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in to create a coupon.");
  }
  const vendorId = request.auth.uid;

  const code = normalizeCouponCode(String(request.data?.code ?? ""));
  if (code.length < MIN_CODE_LEN || code.length > MAX_CODE_LEN) {
    throw new HttpsError(
      "invalid-argument",
      `Coupon code must be ${MIN_CODE_LEN}-${MAX_CODE_LEN} characters.`,
    );
  }
  if (!/^[A-Z0-9]+$/.test(code)) {
    throw new HttpsError(
      "invalid-argument",
      "Coupon code may only contain letters and numbers.",
    );
  }

  const discountTypeRaw = String(request.data?.discountType ?? "").trim().toLowerCase();
  const discountType: CouponDiscountType | "" =
    discountTypeRaw === "flat" || discountTypeRaw === "percent" ? discountTypeRaw : "";
  if (!discountType) {
    throw new HttpsError("invalid-argument", "Choose flat or percent discount.");
  }

  const value = Math.floor(Number(request.data?.value ?? 0));
  if (!Number.isFinite(value) || value <= 0) {
    throw new HttpsError("invalid-argument", "Enter a valid discount value.");
  }
  if (discountType === "percent" && value > MAX_PERCENT_VALUE) {
    throw new HttpsError(
      "invalid-argument",
      `Percent discount cannot exceed ${MAX_PERCENT_VALUE}%.`,
    );
  }
  if (discountType === "flat" && value > MAX_FLAT_VALUE_LKR) {
    throw new HttpsError(
      "invalid-argument",
      `Flat discount cannot exceed Rs. ${MAX_FLAT_VALUE_LKR}.`,
    );
  }

  const expiresAtMs = Number(request.data?.expiresAtMs ?? NaN);
  if (!Number.isFinite(expiresAtMs)) {
    throw new HttpsError("invalid-argument", "Choose when this coupon expires.");
  }
  const now = Date.now();
  if (expiresAtMs <= now) {
    throw new HttpsError("invalid-argument", "Expiry must be in the future.");
  }
  if (expiresAtMs - now > MAX_COUPON_LIFETIME_MS) {
    throw new HttpsError("invalid-argument", "Expiry cannot be more than a year away.");
  }

  const minSubtotalRaw = request.data?.minSubtotalLkr;
  const minSubtotalLkr =
    minSubtotalRaw == null ? undefined : Math.max(0, Math.floor(Number(minSubtotalRaw)));
  if (minSubtotalRaw != null && !Number.isFinite(minSubtotalLkr)) {
    throw new HttpsError("invalid-argument", "Invalid minimum order amount.");
  }

  const maxDiscountRaw = request.data?.maxDiscountLkr;
  const maxDiscountLkr =
    maxDiscountRaw == null ? undefined : Math.max(1, Math.floor(Number(maxDiscountRaw)));
  if (maxDiscountRaw != null && !Number.isFinite(maxDiscountLkr)) {
    throw new HttpsError("invalid-argument", "Invalid maximum discount amount.");
  }

  const maxUsesRaw = request.data?.maxUses;
  const maxUses = maxUsesRaw == null ? undefined : Math.max(1, Math.floor(Number(maxUsesRaw)));
  if (maxUsesRaw != null && !Number.isFinite(maxUses)) {
    throw new HttpsError("invalid-argument", "Invalid usage limit.");
  }

  const perCustomerLimitRaw = request.data?.perCustomerLimit;
  const perCustomerLimit =
    perCustomerLimitRaw == null ? undefined : Math.max(1, Math.floor(Number(perCustomerLimitRaw)));
  if (perCustomerLimitRaw != null && !Number.isFinite(perCustomerLimit)) {
    throw new HttpsError("invalid-argument", "Invalid per-customer limit.");
  }

  const db = getFirestore();
  const vendorSnap = await db.collection("vendors").doc(vendorId).get();
  if (!vendorSnap.exists) {
    throw new HttpsError("permission-denied", "Shop profile required.");
  }
  const approvalStatus = String(vendorSnap.data()?.approvalStatus ?? "").trim().toLowerCase();
  if (approvalStatus && approvalStatus !== "approved") {
    throw new HttpsError(
      "permission-denied",
      "Your shop must be approved before creating coupons.",
    );
  }

  const couponRef = couponRefFor(code);
  await db.runTransaction(async (tx) => {
    const existing = await tx.get(couponRef);
    if (existing.exists) {
      throw new HttpsError("already-exists", "That coupon code is already taken.");
    }
    const doc: CouponDoc = {
      code,
      discountType,
      value,
      active: true,
      storeId: vendorId,
      status: "pending",
      createdBy: "vendor",
      expiresAt: Timestamp.fromMillis(expiresAtMs),
      ...(minSubtotalLkr != null ? {minSubtotalLkr} : {}),
      ...(maxDiscountLkr != null ? {maxDiscountLkr} : {}),
      ...(maxUses != null ? {maxUses} : {}),
      ...(perCustomerLimit != null ? {perCustomerLimit} : {}),
    };
    tx.set(couponRef, {
      ...doc,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });

  return {code, status: "pending"};
});
