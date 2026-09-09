import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {
  onDocumentCreated,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import {CouponDoc} from "./coupons";
import {notifyCustomerOrderEvent} from "./orderNotifications";

const REGION = "asia-south1";

/**
 * Admin-editable via `platform_config/referral` (same convention as
 * `platform_config/fees` in platformConfig.ts). Missing doc/fields fall back
 * to these defaults so redemption never breaks on a config problem.
 */
type ReferralConfig = {
  refereeDiscountLkr: number;
  referrerRewardLkr: number;
};

const DEFAULT_REFERRAL_CONFIG: ReferralConfig = {
  refereeDiscountLkr: 100,
  referrerRewardLkr: 100,
};

async function loadReferralConfig(): Promise<ReferralConfig> {
  try {
    const snap = await getFirestore()
      .collection("platform_config")
      .doc("referral")
      .get();
    if (!snap.exists) {
      return DEFAULT_REFERRAL_CONFIG;
    }
    const d = snap.data() ?? {};
    const referee = Number(d.refereeDiscountLkr);
    const referrer = Number(d.referrerRewardLkr);
    return {
      refereeDiscountLkr:
        Number.isFinite(referee) && referee >= 0 ?
          referee :
          DEFAULT_REFERRAL_CONFIG.refereeDiscountLkr,
      referrerRewardLkr:
        Number.isFinite(referrer) && referrer >= 0 ?
          referrer :
          DEFAULT_REFERRAL_CONFIG.referrerRewardLkr,
    };
  } catch (err) {
    logger.warn("loadReferralConfig failed, using defaults", err);
    return DEFAULT_REFERRAL_CONFIG;
  }
}

function referralCodeCandidate(uid: string, attempt: number): string {
  const base = uid.replace(/[^a-zA-Z0-9]/g, "").slice(0, 8).toUpperCase();
  return attempt === 0 ? base : `${base}${attempt}`;
}

/**
 * Generates and reserves a unique referral code the first time a customer
 * profile is created (profile creation itself happens client-side in
 * phone_auth_controller.dart, but this trigger fires on any write regardless
 * of origin). The `referral_codes/{code} -> {ownerUid}` mapping is
 * server-only (no Firestore rule grants client access) so a code can only be
 * resolved to its owner through the `redeemReferralCode` callable below.
 */
export const onCustomerProfileCreatedGenerateReferralCode = onDocumentCreated(
  {document: "customers/{uid}", region: REGION},
  async (event) => {
    const uid = event.params.uid;
    const data = event.data?.data();
    if (!data || data.referralCode) {
      return;
    }

    const db = getFirestore();
    const customerRef = db.collection("customers").doc(uid);

    for (let attempt = 0; attempt < 5; attempt += 1) {
      const candidate = referralCodeCandidate(uid, attempt);
      const codeRef = db.collection("referral_codes").doc(candidate);
      const reserved = await db.runTransaction(async (tx) => {
        const codeSnap = await tx.get(codeRef);
        if (codeSnap.exists) {
          return false;
        }
        tx.set(codeRef, {
          ownerUid: uid,
          createdAt: FieldValue.serverTimestamp(),
        });
        tx.update(customerRef, {referralCode: candidate});
        return true;
      });
      if (reserved) {
        return;
      }
    }
    logger.error("Could not reserve a referral code after 5 attempts", {uid});
  },
);

/**
 * Redeems someone else's referral code for the calling (new) customer:
 * links `referredBy` and immediately issues a one-time flat-discount coupon
 * for the referee, reusing the existing coupon system (coupons.ts). Only
 * valid for brand-new accounts (no `referredBy` yet, zero prior orders) —
 * everything that must not race is inside a single transaction.
 */
export const redeemReferralCode = onCall(
  {region: REGION},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Sign in to redeem a referral code.",
      );
    }
    const uid = request.auth.uid;
    const rawCode = String(request.data?.code ?? "").trim().toUpperCase();
    if (!rawCode) {
      throw new HttpsError("invalid-argument", "Referral code is required.");
    }

    const db = getFirestore();
    const codeSnap = await db.collection("referral_codes").doc(rawCode).get();
    const ownerUid = String(codeSnap.data()?.ownerUid ?? "");
    if (!codeSnap.exists || !ownerUid) {
      return {success: false, error: "Referral code not found."};
    }
    if (ownerUid === uid) {
      return {success: false, error: "You can't use your own referral code."};
    }

    const config = await loadReferralConfig();
    const couponCode = `REF-${rawCode}-${uid.replace(/[^a-zA-Z0-9]/g, "").slice(0, 6).toUpperCase()}`;
    const customerRef = db.collection("customers").doc(uid);
    const couponRef = db.collection("coupons").doc(couponCode);

    const outcome = await db.runTransaction(async (tx) => {
      const customerSnap = await tx.get(customerRef);
      if (!customerSnap.exists) {
        return {
          ok: false,
          error: "Complete sign-up before applying a referral code.",
        };
      }
      if (customerSnap.data()?.referredBy) {
        return {ok: false, error: "You already used a referral code."};
      }
      const priorOrder = await tx.get(
        db.collection("orders").where("customerId", "==", uid).limit(1),
      );
      if (!priorOrder.empty) {
        return {
          ok: false,
          error: "Referral codes only apply to new accounts.",
        };
      }

      tx.update(customerRef, {
        referredBy: ownerUid,
        referredAt: FieldValue.serverTimestamp(),
      });
      const coupon: CouponDoc = {
        code: couponCode,
        discountType: "flat",
        value: config.refereeDiscountLkr,
        active: true,
        maxUses: 1,
        perCustomerLimit: 1,
      };
      tx.set(couponRef, coupon);
      return {ok: true};
    });

    if (!outcome.ok) {
      return {success: false, error: outcome.error};
    }
    return {
      success: true,
      couponCode,
      discountLkr: config.refereeDiscountLkr,
    };
  },
);

/**
 * Issues the referrer's reward once their referee's FIRST order reaches
 * "delivered" — mirrors the idempotency pattern in
 * riderEarnings.ts#onOrderDeliveredCreditRider (before/after status guard +
 * a transaction that flips a one-time flag so retries/duplicate triggers
 * can't double-issue).
 */
export const onOrderDeliveredIssueReferralReward = onDocumentUpdated(
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

    const customerId = String(after.customerId ?? "").trim();
    if (!customerId) {
      return;
    }

    const db = getFirestore();
    const customerRef = db.collection("customers").doc(customerId);

    const referrerUid = await db.runTransaction(async (tx) => {
      const customerSnap = await tx.get(customerRef);
      const customerData = customerSnap.data();
      if (!customerData) {
        return null;
      }
      const referredBy = String(customerData.referredBy ?? "").trim();
      if (!referredBy || customerData.referralRewardIssued === true) {
        return null;
      }

      // Reward only the referee's first delivered order. The trigger fires
      // after this write commits, so a fresh query already includes it —
      // more than one match means an earlier order got there first.
      const delivered = await tx.get(
        db.collection("orders")
          .where("customerId", "==", customerId)
          .where("status", "==", "delivered")
          .limit(2),
      );
      if (delivered.size > 1) {
        return null;
      }

      tx.update(customerRef, {referralRewardIssued: true});
      return referredBy;
    });

    if (!referrerUid) {
      return;
    }

    const config = await loadReferralConfig();
    const couponCode =
      `REFR-${event.params.orderId.replace(/[^a-zA-Z0-9]/g, "").slice(0, 10).toUpperCase()}`;
    const coupon: CouponDoc = {
      code: couponCode,
      discountType: "flat",
      value: config.referrerRewardLkr,
      active: true,
      maxUses: 1,
      perCustomerLimit: 1,
    };
    await db.collection("coupons").doc(couponCode).set(coupon);

    try {
      await notifyCustomerOrderEvent({
        customerId: referrerUid,
        // No orderId of the referrer's own to deep-link to — omit rather
        // than point their notification at the referee's order.
        orderId: "",
        type: "referral_reward",
        title: "Referral reward earned",
        body:
          `Your friend completed their first order — you got a ` +
          `Rs. ${config.referrerRewardLkr} coupon (${couponCode})!`,
      });
    } catch (err) {
      logger.error("Referral reward notification failed", {
        err,
        referrerUid,
        couponCode,
      });
    }
  },
);
