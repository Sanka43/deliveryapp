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
}

export function normalizeCouponCode(raw: string): string {
  return raw.trim().toUpperCase();
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

async function loadCoupon(code: string): Promise<CouponDoc | null> {
  const snap = await getFirestore().collection("coupons").doc(code).get();
  if (!snap.exists) {
    return null;
  }
  return snap.data() as CouponDoc;
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
    const coupon = await loadCoupon(code);

    const expectedDiscount = coupon
      ? computeDiscountLkr(coupon, subtotal)
      : 0;
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
      await getFirestore()
        .collection("coupons")
        .doc(code)
        .set(
          {usedCount: FieldValue.increment(1)},
          {merge: true},
        );
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
