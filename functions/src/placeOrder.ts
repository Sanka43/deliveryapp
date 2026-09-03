import {createHash, randomBytes, timingSafeEqual} from "crypto";
import {getAuth} from "firebase-admin/auth";
import {FieldValue, getFirestore, GeoPoint} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {defineSecret, defineString} from "firebase-functions/params";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {
  computeDiscountLkr,
  CouponDoc,
  normalizeCouponCode,
} from "./coupons";
import {
  clampTraveledKmToPlausibleRange,
  FALLBACK_FLAT_FEE_LKR,
  feeLkrForActualTripKm,
  feeLkrForDistanceKm,
  haversineKm,
  roundTraveledKm,
} from "./deliveryFee";
import {fetchDrivingDistanceKm} from "./drivingDistance";
import {loadPlatformFeeConfig} from "./platformConfig";
import {computeServiceChargeLkr} from "./serviceCharge";
import {
  guestCustomerIdFromPhone,
  normalizeCustomerPhoneE164,
} from "./phoneNormalize";
import {payHereCheckoutHash, payHereConfig} from "./rideFare";
import {sendSmslenzSms} from "./smslenz";

// Guest-order delivery confirmation (fraud prevention): a vendor-manual order
// whose phone doesn't match an MND account gets a 4-digit code by SMS. The
// rider must collect it from the customer to complete delivery, proving a
// real recipient exists at the address. Same SMSlenz gateway as phoneOtp.ts.
const GUEST_CODE_MAX_ATTEMPTS = 5;
const guestSmsApiKey = defineSecret("SMSLENZ_API_KEY");
const guestSmsUserId = defineString("SMSLENZ_USER_ID", {default: ""});
const guestSmsSenderId = defineString("SMSLENZ_SENDER_ID", {
  default: "MN Delivery",
});

function guestSmsGatewayConfig(): {
  userId: string;
  apiKey: string;
  senderId: string;
} {
  return {
    userId: (process.env.SMSLENZ_USER_ID || guestSmsUserId.value() || "").trim(),
    apiKey: (process.env.SMSLENZ_API_KEY || guestSmsApiKey.value() || "").trim(),
    senderId: (
      process.env.SMSLENZ_SENDER_ID ||
      guestSmsSenderId.value() ||
      "MN Delivery"
    ).trim(),
  };
}

function hashWithSalt(value: string, salt: string): string {
  return createHash("sha256").update(`${salt}:${value}`).digest("hex");
}

function safeEqualHex(a: string, b: string): boolean {
  const bufA = Buffer.from(a, "hex");
  const bufB = Buffer.from(b, "hex");
  if (bufA.length !== bufB.length) {
    return false;
  }
  return timingSafeEqual(bufA, bufB);
}

function generateGuestConfirmationCode(): string {
  const n = randomBytes(2).readUInt16BE(0) % 10000;
  return n.toString().padStart(4, "0");
}


type CartLineIn = {
  productKey: string;
  quantity: number;
  selectedSize?: string;
  extras?: Array<{name: string; priceDelta: number}>;
};

function readIntPrice(raw: unknown): number {
  if (typeof raw === "number" && Number.isFinite(raw)) {
    return Math.max(0, Math.floor(raw));
  }
  if (typeof raw === "string") {
    const n = Number(raw.replace(/[^\d.]/g, ""));
    if (Number.isFinite(n)) {
      return Math.max(0, Math.floor(n));
    }
  }
  return 0;
}

function vendorCoords(vendor: Record<string, unknown>): {
  lat: number;
  lng: number;
} | null {
  const loc = vendor.location;
  if (loc instanceof GeoPoint) {
    return {lat: loc.latitude, lng: loc.longitude};
  }
  if (loc && typeof loc === "object") {
    const lat = Number((loc as {latitude?: unknown}).latitude);
    const lng = Number((loc as {longitude?: unknown}).longitude);
    if (Number.isFinite(lat) && Number.isFinite(lng)) {
      return {lat, lng};
    }
  }
  const lat = Number(vendor.latitude);
  const lng = Number(vendor.longitude);
  if (Number.isFinite(lat) && Number.isFinite(lng)) {
    return {lat, lng};
  }
  return null;
}

function buildTrackingNumber(placedAt: Date, sequence: number): string {
  const yy = String(placedAt.getFullYear() % 100).padStart(2, "0");
  const seq = String(sequence).padStart(5, "0");
  return `MND${yy}${seq}`;
}

function normalizeLineQuantity(raw: unknown, index: number): number {
  const quantity = Number(raw ?? 0);
  if (!Number.isFinite(quantity) || quantity <= 0 || quantity > 999) {
    throw new HttpsError(
      "invalid-argument",
      `Invalid quantity on line ${index + 1}.`,
    );
  }
  const rounded = Math.round(quantity * 100) / 100;
  if (rounded <= 0) {
    throw new HttpsError(
      "invalid-argument",
      `Invalid quantity on line ${index + 1}.`,
    );
  }
  return rounded;
}

function parseLines(raw: unknown): CartLineIn[] {
  if (!Array.isArray(raw) || raw.length === 0 || raw.length > 50) {
    throw new HttpsError("invalid-argument", "Cart items are required (max 50).");
  }
  return raw.map((row, index) => {
    const m = (row ?? {}) as Record<string, unknown>;
    const productKey = String(m.productKey ?? "").trim();
    const quantity = normalizeLineQuantity(m.quantity, index);
    if (!productKey || productKey.length > 160) {
      throw new HttpsError(
        "invalid-argument",
        `Invalid productKey on line ${index + 1}.`,
      );
    }
    const extrasRaw = Array.isArray(m.extras) ? m.extras : [];
    const extras = extrasRaw.map((e) => {
      const em = (e ?? {}) as Record<string, unknown>;
      return {
        name: String(em.name ?? "").trim().slice(0, 80),
        priceDelta: Math.floor(Number(em.priceDelta ?? 0)),
      };
    });
    for (const extra of extras) {
      if (extra.priceDelta !== 0) {
        throw new HttpsError(
          "failed-precondition",
          "Paid extras are not supported for server-priced orders yet.",
        );
      }
    }
    return {
      productKey,
      quantity,
      selectedSize: String(m.selectedSize ?? "").trim().slice(0, 80),
      extras,
    };
  });
}

type StockClaim = {
  ref: FirebaseFirestore.DocumentReference;
  quantity: number;
  available: number;
};

type ResolvedLine = {
  item: Record<string, unknown>;
  /**
   * Present only for a stock-managed product line. Sufficiency (across all
   * lines that might target the same product) is checked by the caller,
   * not here — a single line can't see sibling lines claiming the same
   * product.
   */
  stockClaim?: StockClaim;
};

async function resolveProductLine(
  tx: FirebaseFirestore.Transaction,
  vendorId: string,
  storeName: string,
  line: CartLineIn,
  productByKey: Map<string, Record<string, unknown> & {id: string; ref?: FirebaseFirestore.DocumentReference}>,
  options?: {allowFreeTextSize?: boolean},
): Promise<ResolvedLine> {
  const allowFreeTextSize = options?.allowFreeTextSize === true;
  if (line.productKey.startsWith("offer_")) {
    const offerId = line.productKey.slice("offer_".length);
    const offerRef = getFirestore().collection("offers").doc(offerId);
    const offerSnap = await tx.get(offerRef);
    if (!offerSnap.exists) {
      throw new HttpsError("not-found", `Offer not found: ${offerId}`);
    }
    const offer = offerSnap.data()!;
    if (String(offer.storeId) !== vendorId) {
      throw new HttpsError("failed-precondition", "Offer does not belong to this store.");
    }
    if (String(offer.status) !== "approved") {
      throw new HttpsError("failed-precondition", "Offer is not approved.");
    }
    const endsAt = offer.endsAt as {toMillis?: () => number} | undefined;
    if (endsAt?.toMillis && endsAt.toMillis() < Date.now()) {
      throw new HttpsError("failed-precondition", "Offer has ended.");
    }
    const basePrice = readIntPrice(offer.priceLkr);
    const unitPrice = basePrice;
    const productName = String(offer.title ?? "Offer").trim().slice(0, 120) || "Offer";
    return {
      item: {
        productKey: line.productKey,
        productName,
        storeId: vendorId,
        storeName: String(offer.storeName ?? storeName).slice(0, 120),
        imageUrl: String(offer.imageUrl ?? ""),
        selectedSize: "Offer",
        quantity: line.quantity,
        basePrice,
        sizePriceDelta: 0,
        extras: [],
        unitPrice,
        lineTotal: Math.round(unitPrice * line.quantity),
        offerId,
      },
    };
  }

  const key = line.productKey.trim().toLowerCase();
  const product = productByKey.get(key);
  if (!product) {
    throw new HttpsError(
      "not-found",
      `Product not found or inactive: ${line.productKey}`,
    );
  }
  if (product.active !== true) {
    throw new HttpsError("failed-precondition", `${line.productKey} is unavailable.`);
  }
  const basePrice = readIntPrice(product.price);
  let sizePriceDelta = 0;
  const selectedSize = (line.selectedSize ?? "").trim();
  const sizeOptions = Array.isArray(product.sizeOptions) ? product.sizeOptions : [];
  if (selectedSize && sizeOptions.length > 0) {
    const match = sizeOptions.find(
      (opt) =>
        String((opt as {name?: unknown}).name ?? "").trim().toLowerCase() ===
        selectedSize.toLowerCase(),
    ) as {name?: string; priceLkr?: unknown} | undefined;
    if (!match) {
      if (!allowFreeTextSize) {
        throw new HttpsError(
          "invalid-argument",
          `Size "${selectedSize}" is not available for ${line.productKey}.`,
        );
      }
      // Vendor manual free-text amount label — base price only.
      sizePriceDelta = 0;
    } else {
      sizePriceDelta = readIntPrice(match.priceLkr) - basePrice;
    }
  }
  const unitPrice = basePrice + sizePriceDelta;
  if (unitPrice < 0) {
    throw new HttpsError("failed-precondition", "Invalid product price.");
  }
  const manageStock = product.manageStock === true;
  let stockClaim: StockClaim | undefined;
  if (manageStock) {
    const stockQty = Number(product.stockQty ?? 0);
    if (!Number.isFinite(stockQty)) {
      throw new HttpsError(
        "failed-precondition",
        `Insufficient stock for ${line.productKey}.`,
      );
    }
    if (product.ref) {
      stockClaim = {ref: product.ref, quantity: line.quantity, available: stockQty};
    }
  }
  return {
    item: {
      productKey: line.productKey,
      productName: String(product.name ?? line.productKey).trim().slice(0, 120),
      storeId: vendorId,
      storeName: String(product.storeName ?? product.vendorName ?? storeName).slice(0, 120),
      imageUrl: String(product.imageUrl ?? ""),
      selectedSize,
      quantity: line.quantity,
      basePrice,
      sizePriceDelta,
      extras: (line.extras ?? []).map((e) => ({
        name: e.name,
        priceDelta: 0,
      })),
      unitPrice,
      lineTotal: Math.round(unitPrice * line.quantity),
    },
    stockClaim,
  };
}

/**
 * Resolves priced order lines AND checks+claims stock atomically inside
 * [tx] — reading products fresh via the transaction rather than a plain
 * pre-transaction read, so two concurrent orders can't both pass a stock
 * check against the same stale snapshot. Two lines targeting the same
 * stock-managed product (e.g. two different pack sizes of one item) have
 * their quantities combined before the sufficiency check, so neither line
 * under-claims the shared pool.
 *
 * Returns `stockDecrements` for the caller to apply with `tx.update(...)` —
 * this function only reads; it never writes, so it's safe to call before
 * any other write in the same transaction.
 */
async function resolveOrderLinesTx(
  tx: FirebaseFirestore.Transaction,
  vendorId: string,
  storeName: string,
  lines: CartLineIn[],
  options?: {allowFreeTextSize?: boolean},
): Promise<{
  pricedItems: Record<string, unknown>[];
  subtotal: number;
  stockDecrements: Array<{ref: FirebaseFirestore.DocumentReference; newQty: number}>;
}> {
  const productByKey = await loadProductByKeyMapTx(tx, vendorId);
  const pricedItems: Record<string, unknown>[] = [];
  const claimsByPath = new Map<
    string,
    {ref: FirebaseFirestore.DocumentReference; needed: number; available: number; productKey: string}
  >();

  for (const line of lines) {
    const {item, stockClaim} = await resolveProductLine(
      tx,
      vendorId,
      storeName,
      line,
      productByKey,
      options,
    );
    pricedItems.push(item);
    if (stockClaim) {
      const path = stockClaim.ref.path;
      const existing = claimsByPath.get(path);
      if (existing) {
        existing.needed += stockClaim.quantity;
      } else {
        claimsByPath.set(path, {
          ref: stockClaim.ref,
          needed: stockClaim.quantity,
          available: stockClaim.available,
          productKey: line.productKey,
        });
      }
    }
  }

  const stockDecrements: Array<{ref: FirebaseFirestore.DocumentReference; newQty: number}> = [];
  for (const claim of claimsByPath.values()) {
    if (claim.needed > claim.available) {
      throw new HttpsError(
        "failed-precondition",
        `Insufficient stock for ${claim.productKey}.`,
      );
    }
    stockDecrements.push({ref: claim.ref, newQty: claim.available - claim.needed});
  }

  const storeIds = new Set(pricedItems.map((i) => String(i.storeId ?? "")));
  if (storeIds.size !== 1 || !storeIds.has(vendorId)) {
    throw new HttpsError(
      "failed-precondition",
      "All cart items must belong to one store.",
    );
  }

  const subtotal = pricedItems.reduce(
    (sum, item) => sum + Math.floor(Number(item.lineTotal ?? 0)),
    0,
  );
  if (subtotal < 0) {
    throw new HttpsError("failed-precondition", "Invalid subtotal.");
  }

  return {pricedItems, subtotal, stockDecrements};
}

type PreparedCustomerOrder = {
  vendorId: string;
  storeName: string;
  lines: CartLineIn[];
  deliveryFee: number;
  serviceChargePercent: number;
  deliveryAddress: {line1: string; line2: string; city: string; phone: string};
  deliveryNote: string;
  specialInstructions: string;
  fulfillmentMode: string;
  couponRaw: string;
  dropLat: number | null;
  dropLng: number | null;
  isSelfPickup: boolean;
};

/**
 * Shared validation + pricing for a customer-placed order (cart, address,
 * delivery fee). Used by both the COD and PayHere order-placement callables;
 * they only differ in how the resulting order doc's payment fields are set.
 */
async function prepareCustomerOrder(
  data: Record<string, unknown>,
): Promise<PreparedCustomerOrder> {
  const lines = parseLines(data?.items);
  const resolvedVendorId = String(data?.vendorId ?? "").trim();
  if (!resolvedVendorId) {
    throw new HttpsError("invalid-argument", "vendorId is required.");
  }
  if (resolvedVendorId.length > 128) {
    throw new HttpsError("invalid-argument", "Invalid vendorId.");
  }

  const address = (data?.deliveryAddress ?? {}) as Record<string, unknown>;
  let line1 = String(address.line1 ?? "").trim();
  let line2 = String(address.line2 ?? "").trim();
  let city = String(address.city ?? "").trim();
  const phone = String(address.phone ?? "").trim();

  const fulfillmentRaw = String(data?.fulfillmentMode ?? "delivery").trim();
  const fulfillmentMode =
    fulfillmentRaw === "selfPickup" ? "selfPickup" : "delivery";
  const isSelfPickup = fulfillmentMode === "selfPickup";

  if (phone.length < 8 || phone.length > 20) {
    throw new HttpsError("invalid-argument", "A valid phone is required.");
  }
  if (!isSelfPickup) {
    if (!line1 || line1.length > 200) {
      throw new HttpsError("invalid-argument", "Address line1 is required.");
    }
    if (line2.length > 200) {
      throw new HttpsError("invalid-argument", "Address line2 is too long.");
    }
    if (!city || city.length > 80) {
      throw new HttpsError("invalid-argument", "City is required.");
    }
  } else {
    if (line1.length > 200) {
      throw new HttpsError("invalid-argument", "Address line1 is too long.");
    }
    if (line2.length > 200) {
      throw new HttpsError("invalid-argument", "Address line2 is too long.");
    }
    if (city.length > 80) {
      throw new HttpsError("invalid-argument", "City is too long.");
    }
  }

  const deliveryNote = String(data?.deliveryNote ?? "").trim().slice(0, 500);
  const specialInstructions = String(data?.specialInstructions ?? "")
    .trim()
    .slice(0, 500);
  const couponRaw = String(data?.couponCode ?? "").trim();
  const dropLat =
    data?.dropoffLatitude == null ? null : Number(data.dropoffLatitude);
  const dropLng =
    data?.dropoffLongitude == null ? null : Number(data.dropoffLongitude);

  const db = getFirestore();
  const vendorSnap = await db.collection("vendors").doc(resolvedVendorId).get();
  if (!vendorSnap.exists) {
    throw new HttpsError("not-found", "This store is no longer available.");
  }
  const vendor = vendorSnap.data()!;
  if (vendor.active !== true) {
    throw new HttpsError(
      "failed-precondition",
      "This store is not accepting orders right now.",
    );
  }
  const storeName = String(vendor.name ?? "Store").trim().slice(0, 120) || "Store";

  if (isSelfPickup) {
    const vendorLine = String(vendor.addressLine ?? vendor.address ?? "").trim();
    const vendorCity = String(vendor.city ?? "").trim();
    if (!line1) {
      line1 = (vendorLine || storeName).slice(0, 200);
    }
    if (!city) {
      city = (vendorCity || "Pickup").slice(0, 80);
    }
    if (!line2 && vendorLine && line1 !== vendorLine) {
      line2 = vendorLine.slice(0, 200);
    }
  }
  // Pricing (and, for stock-managed products, the stock check+claim) is
  // resolved later, inside the order-write transaction — a plain read here
  // can't prevent two concurrent orders from both claiming the last unit
  // of a stock-managed product. See `resolveOrderLinesTx`.

  const origin = vendorCoords(vendor);
  const platformFees = await loadPlatformFeeConfig();
  let deliveryFee = 0;
  if (!isSelfPickup) {
    deliveryFee = FALLBACK_FLAT_FEE_LKR;
    if (
      origin &&
      dropLat != null &&
      dropLng != null &&
      Number.isFinite(dropLat) &&
      Number.isFinite(dropLng)
    ) {
      const drivingKm = await fetchDrivingDistanceKm(
        origin.lat,
        origin.lng,
        dropLat,
        dropLng,
      );
      deliveryFee = feeLkrForDistanceKm(
        drivingKm ?? haversineKm(origin.lat, origin.lng, dropLat, dropLng),
        platformFees.delivery,
      );
    }
  }

  return {
    vendorId: resolvedVendorId,
    storeName,
    lines,
    deliveryFee,
    serviceChargePercent: platformFees.serviceChargePercent,
    deliveryAddress: {line1, line2, city, phone},
    deliveryNote,
    specialInstructions,
    fulfillmentMode,
    couponRaw,
    dropLat,
    dropLng,
    isSelfPickup,
  };
}

async function reserveTrackingNumber(
  tx: FirebaseFirestore.Transaction,
): Promise<string> {
  const db = getFirestore();
  const seqRef = db.collection("system").doc("order_sequence");
  const seqSnap = await tx.get(seqRef);
  let currentSeq = 0;
  if (seqSnap.exists) {
    currentSeq = Math.floor(Number(seqSnap.data()?.value ?? 0));
  }
  const nextSeq = currentSeq + 1;
  tx.set(seqRef, {value: nextSeq});
  return buildTrackingNumber(new Date(), nextSeq);
}

async function loadAndPriceCoupon(
  tx: FirebaseFirestore.Transaction,
  couponRaw: string,
  subtotal: number,
): Promise<{code: string; couponRef: FirebaseFirestore.DocumentReference; discount: number}> {
  const db = getFirestore();
  const code = normalizeCouponCode(couponRaw);
  const couponRef = db.collection("coupons").doc(code);
  const couponSnap = await tx.get(couponRef);
  if (!couponSnap.exists) {
    throw new HttpsError("not-found", "Coupon not found.");
  }
  const coupon = couponSnap.data() as CouponDoc;
  const discount = computeDiscountLkr(coupon, subtotal);
  if (discount <= 0) {
    throw new HttpsError(
      "failed-precondition",
      "This coupon cannot be applied to your cart.",
    );
  }
  const usedCount = Number(coupon.usedCount ?? 0);
  const maxUses = coupon.maxUses;
  if (maxUses != null && usedCount >= maxUses) {
    throw new HttpsError("failed-precondition", "Coupon usage limit reached.");
  }
  return {code, couponRef, discount};
}

/** Immediately-placed orders (COD): price the coupon and reserve a use now. */
async function consumeCouponAndSequence(
  tx: FirebaseFirestore.Transaction,
  couponRaw: string,
  subtotal: number,
): Promise<{discount: number; couponCode: string | undefined; trackingNumber: string}> {
  let discount = 0;
  let couponCode: string | undefined;
  if (couponRaw) {
    const {code, couponRef, discount: d} = await loadAndPriceCoupon(
      tx,
      couponRaw,
      subtotal,
    );
    tx.set(couponRef, {usedCount: FieldValue.increment(1)}, {merge: true});
    discount = d;
    couponCode = code;
  }
  const trackingNumber = await reserveTrackingNumber(tx);
  return {discount, couponCode, trackingNumber};
}

/**
 * PayHere checkout drafts: price the coupon for display/total purposes but
 * don't reserve a use yet — the customer hasn't paid, and may never come
 * back to this draft. The use is reserved only once payment actually
 * confirms (`markOrderPaidAndPlace`), so an abandoned checkout can't burn a
 * limited-use coupon with zero completed orders.
 */
async function previewCouponAndSequence(
  tx: FirebaseFirestore.Transaction,
  couponRaw: string,
  subtotal: number,
): Promise<{discount: number; couponCode: string | undefined; trackingNumber: string}> {
  let discount = 0;
  let couponCode: string | undefined;
  if (couponRaw) {
    const {code, discount: d} = await loadAndPriceCoupon(
      tx,
      couponRaw,
      subtotal,
    );
    discount = d;
    couponCode = code;
  }
  const trackingNumber = await reserveTrackingNumber(tx);
  return {discount, couponCode, trackingNumber};
}

/**
 * Server-authoritative COD order placement.
 * Recomputes line prices from products/offers, delivery fee, and coupons.
 */
export const placeCashOnDeliveryOrder = onCall(
  {region: "asia-south1"},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in to place an order.");
    }
    const uid = request.auth.uid;
    const prepared = await prepareCustomerOrder(request.data ?? {});

    const db = getFirestore();
    const orderRef = db.collection("orders").doc();

    const result = await db.runTransaction(async (tx) => {
      // Reads only, before any writes — safe to run first in this
      // transaction (see resolveOrderLinesTx doc comment).
      const {pricedItems, subtotal, stockDecrements} = await resolveOrderLinesTx(
        tx,
        prepared.vendorId,
        prepared.storeName,
        prepared.lines,
      );

      const {discount, couponCode, trackingNumber} =
        await consumeCouponAndSequence(tx, prepared.couponRaw, subtotal);

      const serviceCharge = computeServiceChargeLkr(
        subtotal,
        prepared.serviceChargePercent,
      );
      const total = Math.max(
        0,
        subtotal - discount + prepared.deliveryFee + serviceCharge,
      );
      const payload: Record<string, unknown> = {
        trackingNumber,
        customerId: uid,
        vendorId: prepared.vendorId,
        vendorStoreId: prepared.vendorId,
        storeName: prepared.storeName,
        status: "placed",
        paymentMethod: "cashOnDelivery",
        items: pricedItems,
        subtotal,
        discount,
        deliveryFee: prepared.deliveryFee,
        serviceCharge,
        total,
        // Fixed-fee COD orders never go through completeDeliveryOrder (that's
        // actual-trip-only, see placeVendorManualOrder) — the rider's own
        // status update just flips status:'delivered' with no recalculation.
        // So the shop's product cost has to be finalized here at placement,
        // the only point where onOrderDeliveredCreditRider is guaranteed to
        // find it when the trigger reads the order later.
        productCashLkr: Math.max(0, subtotal - discount),
        productCashStatus: "owed",
        deliveryAddress: prepared.deliveryAddress,
        deliveryNote: prepared.deliveryNote,
        specialInstructions: prepared.specialInstructions,
        fulfillmentMode: prepared.fulfillmentMode,
        serverPlaced: true,
        couponVerified: Boolean(couponCode),
        createdAt: FieldValue.serverTimestamp(),
      };
      if (couponCode) {
        payload.couponCode = couponCode;
      }
      if (
        !prepared.isSelfPickup &&
        prepared.dropLat != null &&
        prepared.dropLng != null &&
        Number.isFinite(prepared.dropLat) &&
        Number.isFinite(prepared.dropLng)
      ) {
        payload.dropoffLatitude = prepared.dropLat;
        payload.dropoffLongitude = prepared.dropLng;
      }
      tx.set(orderRef, payload);
      // Placed immediately (not a draft) — this order is real now, so the
      // stock claim commits atomically with it, closing the gap where two
      // concurrent checkouts could both win the last unit.
      for (const d of stockDecrements) {
        tx.update(d.ref, {stockQty: d.newQty});
      }
      return {
        orderId: orderRef.id,
        trackingNumber,
        total,
        subtotal,
        discount,
        deliveryFee: prepared.deliveryFee,
        serviceCharge,
      };
    });

    return result;
  },
);

/**
 * Creates a `draft_payment` order and returns PayHere checkout form fields.
 * The order becomes real (`status: 'placed'`) only once `payHereNotify`
 * confirms payment via `markOrderPaidAndPlace` — mirrors `createPayHereCheckout`
 * for ride trips.
 */
export const createPayHereCheckoutForOrder = onCall(
  {region: "asia-south1"},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in to pay for an order.");
    }
    const uid = request.auth.uid;
    const prepared = await prepareCustomerOrder(request.data ?? {});
    const firstName =
      String(request.data?.firstName ?? "Customer").trim().slice(0, 80) ||
      "Customer";
    const lastName =
      String(request.data?.lastName ?? "MND").trim().slice(0, 80) || "MND";
    const email = String(request.data?.email ?? "").trim();

    const cfg = payHereConfig();
    const db = getFirestore();
    const orderRef = db.collection("orders").doc();
    const orderId = orderRef.id;

    const result = await db.runTransaction(async (tx) => {
      // Prices and checks stock (throws if insufficient), but deliberately
      // does NOT apply `stockDecrements` — this is only a draft, payment
      // hasn't confirmed, and an abandoned PayHere checkout must not
      // permanently reduce stock (same reasoning as coupon `usedCount` only
      // being consumed on confirmed payment, not draft creation). The
      // actual decrement happens in `markOrderPaidAndPlace` once this draft
      // becomes a real order.
      const {pricedItems, subtotal} = await resolveOrderLinesTx(
        tx,
        prepared.vendorId,
        prepared.storeName,
        prepared.lines,
      );

      const {discount, couponCode, trackingNumber} =
        await previewCouponAndSequence(tx, prepared.couponRaw, subtotal);

      const serviceCharge = computeServiceChargeLkr(
        subtotal,
        prepared.serviceChargePercent,
      );
      const total = Math.max(
        0,
        subtotal - discount + prepared.deliveryFee + serviceCharge,
      );
      const payload: Record<string, unknown> = {
        trackingNumber,
        customerId: uid,
        vendorId: prepared.vendorId,
        vendorStoreId: prepared.vendorId,
        storeName: prepared.storeName,
        status: "draft_payment",
        paymentMethod: "payhere",
        paymentStatus: "pending",
        paymentProvider: "payhere",
        customerFirstName: firstName,
        customerLastName: lastName,
        customerEmail: email || `${uid}@mnd.local`,
        items: pricedItems,
        subtotal,
        discount,
        deliveryFee: prepared.deliveryFee,
        serviceCharge,
        total,
        deliveryAddress: prepared.deliveryAddress,
        deliveryNote: prepared.deliveryNote,
        specialInstructions: prepared.specialInstructions,
        fulfillmentMode: prepared.fulfillmentMode,
        serverPlaced: true,
        couponVerified: Boolean(couponCode),
        createdAt: FieldValue.serverTimestamp(),
      };
      if (couponCode) {
        payload.couponCode = couponCode;
      }
      if (
        !prepared.isSelfPickup &&
        prepared.dropLat != null &&
        prepared.dropLng != null &&
        Number.isFinite(prepared.dropLat) &&
        Number.isFinite(prepared.dropLng)
      ) {
        payload.dropoffLatitude = prepared.dropLat;
        payload.dropoffLongitude = prepared.dropLng;
      }
      tx.set(orderRef, payload);
      return {trackingNumber, total};
    });

    const amount = result.total.toFixed(2);
    const currency = "LKR";
    const hash = payHereCheckoutHash(
      cfg.merchantId,
      orderId,
      amount,
      currency,
      cfg.merchantSecret,
    );
    const checkoutUrl = cfg.sandbox
      ? "https://sandbox.payhere.lk/pay/checkout"
      : "https://www.payhere.lk/pay/checkout";

    return {
      orderId,
      trackingNumber: result.trackingNumber,
      checkoutUrl,
      checkoutPageUrl: `${cfg.checkoutPageUrl}?type=order&id=${encodeURIComponent(orderId)}`,
      sandbox: cfg.sandbox,
      fields: {
        merchant_id: cfg.merchantId,
        return_url: cfg.returnUrl,
        cancel_url: cfg.cancelUrl,
        notify_url: cfg.notifyUrl,
        order_id: orderId,
        items: `MND Order ${result.trackingNumber} (${prepared.storeName})`,
        currency,
        amount,
        first_name: firstName,
        last_name: lastName,
        email: email || `${uid}@mnd.local`,
        phone: prepared.deliveryAddress.phone,
        address: prepared.deliveryAddress.line1.slice(0, 100),
        city: prepared.deliveryAddress.city || "Sri Lanka",
        country: "Sri Lanka",
        hash,
      },
    };
  },
);

export const ELIGIBLE_STATUSES_FOR_LATE_PAYHERE = new Set([
  "placed",
  "confirmed",
  "preparing",
  "ready",
  "out_for_delivery",
  "picked_up",
  "on_the_way",
]);

/**
 * Lets a customer pay online (PayHere) for an order that was placed as
 * Cash on Delivery, at any point before delivery. Reuses the order's
 * existing id/total — does not mutate anything; the order is only marked
 * paid once `payHereNotify` confirms payment via
 * `markExistingOrderPaidOnline`.
 */
export const createPayHereCheckoutForExistingOrder = onCall(
  {region: "asia-south1"},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in to pay for an order.");
    }
    const uid = request.auth.uid;
    const orderId = String(request.data?.orderId ?? "").trim();
    if (!orderId) {
      throw new HttpsError("invalid-argument", "orderId is required.");
    }
    const firstName =
      String(request.data?.firstName ?? "Customer").trim().slice(0, 80) ||
      "Customer";
    const lastName =
      String(request.data?.lastName ?? "MND").trim().slice(0, 80) || "MND";
    const email = String(request.data?.email ?? "").trim();

    const db = getFirestore();
    const orderRef = db.collection("orders").doc(orderId);
    const snap = await orderRef.get();
    if (!snap.exists) {
      throw new HttpsError("not-found", "Order not found.");
    }
    const data = snap.data()!;
    if (String(data.customerId ?? "") !== uid) {
      throw new HttpsError(
        "permission-denied",
        "You are not allowed to pay for this order.",
      );
    }
    const paymentMethod = String(data.paymentMethod ?? "").trim();
    const paymentStatus = String(data.paymentStatus ?? "").trim();
    if (paymentMethod !== "cashOnDelivery" || paymentStatus === "paid") {
      throw new HttpsError(
        "failed-precondition",
        "This order is not eligible for online payment.",
      );
    }
    const status = String(data.status ?? "").trim();
    if (!ELIGIBLE_STATUSES_FOR_LATE_PAYHERE.has(status)) {
      throw new HttpsError(
        "failed-precondition",
        `Order cannot be paid online from status "${status}".`,
      );
    }

    const total = Math.max(0, Math.floor(Number(data.total ?? NaN)));
    if (!Number.isFinite(total)) {
      throw new HttpsError("failed-precondition", "Order total is missing.");
    }
    const trackingNumber = String(data.trackingNumber ?? "").trim();
    const storeName = String(data.storeName ?? "Store").trim() || "Store";
    const deliveryAddress =
      (data.deliveryAddress as Record<string, unknown> | undefined) ?? {};

    const cfg = payHereConfig();
    const amount = total.toFixed(2);
    const currency = "LKR";
    const hash = payHereCheckoutHash(
      cfg.merchantId,
      orderId,
      amount,
      currency,
      cfg.merchantSecret,
    );
    const checkoutUrl = cfg.sandbox
      ? "https://sandbox.payhere.lk/pay/checkout"
      : "https://www.payhere.lk/pay/checkout";

    return {
      orderId,
      trackingNumber,
      checkoutUrl,
      checkoutPageUrl: `${cfg.checkoutPageUrl}?type=order&id=${encodeURIComponent(orderId)}`,
      sandbox: cfg.sandbox,
      fields: {
        merchant_id: cfg.merchantId,
        return_url: cfg.returnUrl,
        cancel_url: cfg.cancelUrl,
        notify_url: cfg.notifyUrl,
        order_id: orderId,
        items: `MND Order ${trackingNumber} (${storeName})`,
        currency,
        amount,
        first_name: firstName,
        last_name: lastName,
        email: email || `${uid}@mnd.local`,
        phone: String(deliveryAddress.phone ?? ""),
        address: String(deliveryAddress.line1 ?? "").slice(0, 100),
        city: String(deliveryAddress.city ?? "") || "Sri Lanka",
        country: "Sri Lanka",
        hash,
      },
    };
  },
);

/**
 * Confirms a `draft_payment` order as paid and makes it real (`status:
 * 'placed'`). Called by `payHereNotify` once PayHere confirms payment.
 * Idempotent: a no-op if the order has already left `draft_payment`.
 */
export async function markOrderPaidAndPlace(
  orderId: string,
  provider: string,
  transactionId?: string,
  paidAmountLkr?: number,
  paidCurrency?: string,
): Promise<void> {
  const ref = getFirestore().collection("orders").doc(orderId);
  await getFirestore().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) {
      throw new HttpsError("not-found", "Order not found.");
    }
    const data = snap.data()!;
    const status = String(data.status ?? "");
    if (status !== "draft_payment") {
      return;
    }
    if (paidAmountLkr != null) {
      const expectedTotal = Math.floor(Number(data.total ?? NaN));
      if (!Number.isFinite(expectedTotal)) {
        throw new HttpsError("failed-precondition", "Order total is missing.");
      }
      const currency = String(paidCurrency ?? "LKR").trim().toUpperCase();
      if (currency !== "LKR") {
        throw new HttpsError("failed-precondition", "Unsupported payment currency.");
      }
      const paidCents = Math.round(Number(paidAmountLkr) * 100);
      const expectedCents = Math.round(expectedTotal * 100);
      if (!Number.isFinite(paidCents) || paidCents !== expectedCents) {
        throw new HttpsError(
          "failed-precondition",
          `Paid amount ${paidAmountLkr} does not match order total ${expectedTotal}.`,
        );
      }
    }
    // Stock, like the coupon use below, was only checked (not claimed) when
    // this draft was created (`createPayHereCheckoutForOrder` deliberately
    // skips applying its stock decrements) — claim it now that payment has
    // actually confirmed. Resolved before any writes in this transaction
    // (the coupon block below writes), matching resolveOrderLinesTx's
    // reads-before-writes contract.
    const vendorId = String(data.vendorId ?? "").trim();
    const items = Array.isArray(data.items) ? data.items : [];
    const stockClaims = new Map<
      string,
      {ref: FirebaseFirestore.DocumentReference; needed: number; available: number}
    >();
    if (vendorId && items.length > 0) {
      const productByKey = await loadProductByKeyMapTx(tx, vendorId);
      for (const rawItem of items) {
        const item = (rawItem ?? {}) as Record<string, unknown>;
        const productKey = String(item.productKey ?? "").trim().toLowerCase();
        const quantity = Number(item.quantity ?? 0);
        if (!productKey || !Number.isFinite(quantity) || quantity <= 0) {
          continue;
        }
        const product = productByKey.get(productKey);
        if (!product || product.manageStock !== true) {
          continue;
        }
        const path = product.ref.path;
        const existing = stockClaims.get(path);
        if (existing) {
          existing.needed += quantity;
        } else {
          stockClaims.set(path, {
            ref: product.ref,
            needed: quantity,
            available: Number(product.stockQty ?? 0),
          });
        }
      }
    }

    // The coupon use was only priced (not reserved) when this draft was
    // created (`previewCouponAndSequence`) — reserve it now that payment has
    // actually confirmed, so an abandoned checkout never burns a use.
    const couponCode = String(data.couponCode ?? "").trim();
    if (couponCode) {
      const couponRef = getFirestore().collection("coupons").doc(couponCode);
      const couponSnap = await tx.get(couponRef);
      if (couponSnap.exists) {
        const coupon = couponSnap.data() as CouponDoc;
        const usedCount = Number(coupon.usedCount ?? 0);
        const maxUses = coupon.maxUses;
        if (maxUses == null || usedCount < maxUses) {
          tx.set(
            couponRef,
            {usedCount: FieldValue.increment(1)},
            {merge: true},
          );
        }
      }
    }

    const patch: Record<string, unknown> = {
      paymentStatus: "paid",
      paymentProvider: provider,
      paymentUpdatedAt: FieldValue.serverTimestamp(),
      paidAt: FieldValue.serverTimestamp(),
      status: "placed",
    };
    if (transactionId) {
      patch.paymentTransactionId = transactionId;
    }
    // Payment already succeeded — never block on stock here. Clamp at 0 and
    // flag rather than go negative or reject an already-paid order.
    let stockOversold = false;
    for (const claim of stockClaims.values()) {
      const newQty = claim.available - claim.needed;
      if (newQty < 0) {
        stockOversold = true;
      }
      tx.update(claim.ref, {stockQty: Math.max(0, newQty)});
    }
    if (stockOversold) {
      patch.stockOversoldFlagged = true;
    }
    tx.update(ref, patch);
  });
}

/**
 * Confirms online payment for an order that was placed as Cash on Delivery
 * and is already past `draft_payment` (created by `placeCashOnDeliveryOrder`
 * or a vendor-manual COD order). Flips `paymentMethod` to `payhere` so the
 * customer app's `isOnlinePayment`/`isPaid` UI and the rider app's
 * prepaid-online check both key off the same fields already used for
 * checkout-time online payments. Never touches `status`. Idempotent.
 */
export async function markExistingOrderPaidOnline(
  orderId: string,
  transactionId: string | undefined,
  paidAmountLkr: number | undefined,
  paidCurrency: string | undefined,
): Promise<void> {
  const ref = getFirestore().collection("orders").doc(orderId);
  await getFirestore().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) {
      throw new HttpsError("not-found", "Order not found.");
    }
    const data = snap.data()!;
    if (
      data.paymentStatus === "paid" &&
      transactionId &&
      data.paymentTransactionId === transactionId
    ) {
      return;
    }
    if (paidAmountLkr != null) {
      const expectedTotal = Math.floor(Number(data.total ?? NaN));
      if (!Number.isFinite(expectedTotal)) {
        throw new HttpsError("failed-precondition", "Order total is missing.");
      }
      const currency = String(paidCurrency ?? "LKR").trim().toUpperCase();
      if (currency !== "LKR") {
        throw new HttpsError("failed-precondition", "Unsupported payment currency.");
      }
      const paidCents = Math.round(Number(paidAmountLkr) * 100);
      const expectedCents = Math.round(expectedTotal * 100);
      if (!Number.isFinite(paidCents) || paidCents !== expectedCents) {
        throw new HttpsError(
          "failed-precondition",
          `Paid amount ${paidAmountLkr} does not match order total ${expectedTotal}.`,
        );
      }
    }
    const patch: Record<string, unknown> = {
      paymentMethod: "payhere",
      originalPaymentMethod: data.paymentMethod ?? "cashOnDelivery",
      paymentStatus: "paid",
      paymentProvider: "payhere",
      paymentUpdatedAt: FieldValue.serverTimestamp(),
      paidAt: FieldValue.serverTimestamp(),
    };
    if (transactionId) {
      patch.paymentTransactionId = transactionId;
    }
    tx.update(ref, patch);
  });
}

async function resolveCallerVendorStore(uid: string): Promise<{
  vendorId: string;
  vendor: Record<string, unknown>;
  storeName: string;
}> {
  const db = getFirestore();
  const selfSnap = await db.collection("vendors").doc(uid).get();
  if (!selfSnap.exists) {
    const customerSnap = await db.collection("customers").doc(uid).get();
    const linked = String(customerSnap.data()?.vendorStoreId ?? "").trim();
    if (!linked) {
      throw new HttpsError(
        "permission-denied",
        "Only registered vendors can create orders.",
      );
    }
    const linkedSnap = await db.collection("vendors").doc(linked).get();
    if (!linkedSnap.exists) {
      throw new HttpsError("not-found", "Vendor storefront not found.");
    }
    const vendor = linkedSnap.data() as Record<string, unknown>;
    const owner = String(vendor.uid ?? "").trim();
    if (owner && owner !== uid) {
      throw new HttpsError(
        "permission-denied",
        "You are not allowed to create orders for this store.",
      );
    }
    if (vendor.active !== true) {
      throw new HttpsError(
        "failed-precondition",
        "This store is not accepting orders right now.",
      );
    }
    const storeName =
      String(vendor.name ?? "Store").trim().slice(0, 120) || "Store";
    return {vendorId: linked, vendor, storeName};
  }

  const self = selfSnap.data() as Record<string, unknown>;
  let vendorId = uid;
  const profileVs = String(self.vendorStoreId ?? "").trim();
  if (profileVs && profileVs !== uid) {
    const linkSnap = await db.collection("vendors").doc(profileVs).get();
    const owner = String(linkSnap.data()?.uid ?? "").trim();
    if (linkSnap.exists && owner === uid) {
      vendorId = profileVs;
    }
  }

  const vendorSnap =
    vendorId === uid ? selfSnap : await db.collection("vendors").doc(vendorId).get();
  if (!vendorSnap.exists) {
    throw new HttpsError("not-found", "Vendor storefront not found.");
  }
  const vendor = vendorSnap.data() as Record<string, unknown>;
  if (vendor.active !== true) {
    throw new HttpsError(
      "failed-precondition",
      "This store is not accepting orders right now.",
    );
  }
  const storeName =
    String(vendor.name ?? "Store").trim().slice(0, 120) || "Store";
  return {vendorId, vendor, storeName};
}

/** Transactional so a stock check reads the same snapshot the order write commits against. */
async function loadProductByKeyMapTx(
  tx: FirebaseFirestore.Transaction,
  vendorId: string,
): Promise<
  Map<string, Record<string, unknown> & {id: string; ref: FirebaseFirestore.DocumentReference}>
> {
  const productsSnap = await tx.get(
    getFirestore().collection("products").where("storeId", "==", vendorId),
  );
  const productByKey = new Map<
    string,
    Record<string, unknown> & {id: string; ref: FirebaseFirestore.DocumentReference}
  >();
  for (const doc of productsSnap.docs) {
    const data = doc.data() as Record<string, unknown>;
    const keys = [
      String(data.lookupKey ?? "").trim().toLowerCase(),
      String(data.productId ?? "").trim().toLowerCase(),
      doc.id.toLowerCase(),
    ];
    for (const k of keys) {
      if (k) {
        productByKey.set(k, {...data, id: doc.id, ref: doc.ref});
      }
    }
  }
  return productByKey;
}

async function resolveCustomerForVendorOrder(phoneRaw: unknown): Promise<{
  customerId: string;
  customerName: string;
  phoneE164: string;
  isGuest: boolean;
  suggestedAddress: {
    line1: string;
    line2: string;
    city: string;
    phone: string;
  } | null;
}> {
  const normalized = normalizeCustomerPhoneE164(phoneRaw);
  if (!normalized.ok) {
    throw new HttpsError("invalid-argument", normalized.error);
  }
  const {e164, digits} = normalized;

  try {
    const user = await getAuth().getUserByPhoneNumber(e164);
    const customerSnap = await getFirestore()
      .collection("customers")
      .doc(user.uid)
      .get();
    const data = customerSnap.data() ?? {};
    const displayName =
      String(data.displayName ?? user.displayName ?? "").trim().slice(0, 120) ||
      "Customer";

    let suggestedAddress: {
      line1: string;
      line2: string;
      city: string;
      phone: string;
    } | null = null;
    const addrSnap = await getFirestore()
      .collection("customers")
      .doc(user.uid)
      .collection("saved_addresses")
      .orderBy("createdAt", "asc")
      .limit(20)
      .get();
    if (!addrSnap.empty) {
      const preferred =
        addrSnap.docs.find((d) => d.data().isDefault === true) ??
        addrSnap.docs[0];
      const a = preferred.data();
      suggestedAddress = {
        line1: String(a.line1 ?? "").trim().slice(0, 200),
        line2: String(a.line2 ?? "").trim().slice(0, 200),
        city: String(a.city ?? "").trim().slice(0, 80),
        phone: String(a.phone ?? e164).trim().slice(0, 20) || e164,
      };
    }

    return {
      customerId: user.uid,
      customerName: displayName,
      phoneE164: e164,
      isGuest: false,
      suggestedAddress,
    };
  } catch (err: unknown) {
    const code =
      err && typeof err === "object" && "code" in err
        ? String((err as {code?: unknown}).code)
        : "";
    if (code !== "auth/user-not-found") {
      throw err;
    }
  }

  return {
    customerId: guestCustomerIdFromPhone(digits),
    customerName: "",
    phoneE164: e164,
    isGuest: true,
    suggestedAddress: null,
  };
}

/**
 * Vendor phone lookup for the create-order wizard.
 */
export const lookupVendorOrderCustomer = onCall(
  {region: "asia-south1"},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in to look up a customer.");
    }
    await resolveCallerVendorStore(request.auth.uid);
    const resolved = await resolveCustomerForVendorOrder(request.data?.phone);
    return {
      found: !resolved.isGuest,
      isGuest: resolved.isGuest,
      customerId: resolved.isGuest ? null : resolved.customerId,
      displayName: resolved.customerName || null,
      phoneE164: resolved.phoneE164,
      suggestedAddress: resolved.suggestedAddress,
    };
  },
);

/**
 * Vendor-created COD delivery order (phone / walk-in).
 * Starts at `confirmed` and uses the same rider pool on Mark ready.
 */
export const placeVendorManualOrder = onCall(
  {region: "asia-south1", secrets: [guestSmsApiKey]},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in to create an order.");
    }
    const vendorUid = request.auth.uid;
    const {vendorId, storeName} =
      await resolveCallerVendorStore(vendorUid);

    const phoneRaw =
      request.data?.customerPhone ??
      (request.data?.deliveryAddress as Record<string, unknown> | undefined)
        ?.phone;
    const resolvedCustomer = await resolveCustomerForVendorOrder(phoneRaw);

    // Found (non-guest) accounts: never trust a client-supplied name, always
    // use the account's own name. Guest: vendor-typed name, or a short
    // default label so the field can be left blank.
    let customerName: string;
    if (resolvedCustomer.isGuest) {
      const typed = String(request.data?.customerName ?? "").trim().slice(0, 120);
      customerName =
        typed || `Guest ${resolvedCustomer.phoneE164.slice(-4)}`;
    } else {
      customerName = resolvedCustomer.customerName || "Customer";
    }

    const address = (request.data?.deliveryAddress ?? {}) as Record<
      string,
      unknown
    >;
    const line1 = String(address.line1 ?? "").trim();
    const line2 = String(address.line2 ?? "").trim();
    const city = String(address.city ?? "").trim();
    const phone =
      String(address.phone ?? "").trim() || resolvedCustomer.phoneE164;

    if (phone.length < 8 || phone.length > 20) {
      throw new HttpsError("invalid-argument", "A valid phone is required.");
    }
    if (!line1 || line1.length > 200) {
      throw new HttpsError("invalid-argument", "Address line1 is required.");
    }
    if (line2.length > 200) {
      throw new HttpsError("invalid-argument", "Address line2 is too long.");
    }
    if (!city || city.length > 80) {
      throw new HttpsError("invalid-argument", "City is required.");
    }

    const productsPaidRaw = request.data?.productsPaid;
    if (typeof productsPaidRaw !== "boolean") {
      throw new HttpsError(
        "invalid-argument",
        "productsPaid (true/false) is required.",
      );
    }
    const productsPaid = productsPaidRaw;

    const dropLatRaw = request.data?.dropoffLatitude;
    const dropLngRaw = request.data?.dropoffLongitude;
    const dropLat =
      dropLatRaw === undefined || dropLatRaw === null
        ? null
        : Number(dropLatRaw);
    const dropLng =
      dropLngRaw === undefined || dropLngRaw === null
        ? null
        : Number(dropLngRaw);
    const hasDropoff =
      dropLat !== null &&
      dropLng !== null &&
      Number.isFinite(dropLat) &&
      Number.isFinite(dropLng);
    if (
      (dropLatRaw !== undefined && dropLatRaw !== null && !Number.isFinite(Number(dropLatRaw))) ||
      (dropLngRaw !== undefined && dropLngRaw !== null && !Number.isFinite(Number(dropLngRaw)))
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Dropoff latitude/longitude must be valid numbers when provided.",
      );
    }

    const deliveryNote = String(request.data?.deliveryNote ?? "")
      .trim()
      .slice(0, 500);
    const specialInstructions = String(request.data?.specialInstructions ?? "")
      .trim()
      .slice(0, 500);

    // Flash/courier-style order: no catalogue picking. Vendor already agreed
    // a single package price with the customer by phone, so there's no
    // catalogue price to protect here — this order is delivery-fee-only for
    // platform commission, not a menu sale.
    const packagePriceRaw = request.data?.packagePriceLkr;
    const packagePrice = Math.floor(Number(packagePriceRaw));
    if (!Number.isFinite(packagePrice) || packagePrice <= 0 || packagePrice > 10_000_000) {
      throw new HttpsError("invalid-argument", "Enter a valid package price.");
    }
    const packageDescription = String(request.data?.packageDescription ?? "")
      .trim()
      .slice(0, 300);

    const pricedItems: Record<string, unknown>[] = [
      {
        productKey: "custom_package",
        productName: packageDescription || "Package",
        storeId: vendorId,
        storeName,
        imageUrl: "",
        selectedSize: "",
        quantity: 1,
        basePrice: packagePrice,
        sizePriceDelta: 0,
        extras: [],
        unitPrice: packagePrice,
        lineTotal: packagePrice,
        isCustomLine: true,
      },
    ];

    const subtotal = packagePrice;

    // Fee is finalized from rider path KM on deliver (`completeDeliveryOrder`).
    const deliveryFee = 0;
    const discount = 0;
    const platformFees = await loadPlatformFeeConfig();
    const serviceCharge = computeServiceChargeLkr(
      subtotal,
      platformFees.serviceChargePercent,
    );
    // Even when the customer already paid the shop directly for the
    // products (productsPaid), the rider still owes the platform service
    // charge (plus delivery fee, finalized later) — so the placeholder
    // total is never a flat 0.
    const total = productsPaid
      ? serviceCharge
      : Math.max(0, subtotal - discount + serviceCharge);

    const db = getFirestore();
    const placedAt = new Date();
    const orderRef = db.collection("orders").doc();
    const seqRef = db.collection("system").doc("order_sequence");

    const result = await db.runTransaction(async (tx) => {
      const seqSnap = await tx.get(seqRef);
      let currentSeq = 0;
      if (seqSnap.exists) {
        currentSeq = Math.floor(Number(seqSnap.data()?.value ?? 0));
      }
      const nextSeq = currentSeq + 1;
      tx.set(seqRef, {value: nextSeq});

      const trackingNumber = buildTrackingNumber(placedAt, nextSeq);
      const payload: Record<string, unknown> = {
        trackingNumber,
        customerId: resolvedCustomer.customerId,
        customerName,
        customerPhoneE164: resolvedCustomer.phoneE164,
        isGuestCustomer: resolvedCustomer.isGuest,
        orderSource: "vendor_manual",
        createdByVendorUid: vendorUid,
        vendorId,
        vendorStoreId: vendorId,
        storeName,
        status: "confirmed",
        paymentMethod: "cashOnDelivery",
        productsPaid,
        items: pricedItems,
        subtotal,
        discount,
        deliveryFee,
        serviceCharge,
        deliveryFeeMode: "actual_trip",
        total,
        deliveryAddress: {line1, line2, city, phone},
        deliveryNote,
        specialInstructions,
        fulfillmentMode: "delivery",
        serverPlaced: true,
        couponVerified: false,
        createdAt: FieldValue.serverTimestamp(),
        vendorStatusUpdatedAt: FieldValue.serverTimestamp(),
      };
      if (hasDropoff) {
        payload.dropoffLatitude = dropLat;
        payload.dropoffLongitude = dropLng;
      }
      tx.set(orderRef, payload);
      return {
        orderId: orderRef.id,
        trackingNumber,
        total,
        subtotal,
        discount,
        deliveryFee,
        serviceCharge,
        productsPaid,
        customerId: resolvedCustomer.customerId,
        isGuestCustomer: resolvedCustomer.isGuest,
      };
    });

    // Guest phone (no MND account): send the delivery confirmation code by
    // SMS. Done after the order commits — a network call has no place inside
    // a transaction that may retry. A send failure doesn't fail order
    // creation; the vendor sees `guestSmsSent: false` and can follow up.
    let guestSmsSent: boolean | undefined;
    if (resolvedCustomer.isGuest) {
      const code = generateGuestConfirmationCode();
      const codeSalt = randomBytes(16).toString("hex");
      const codeHash = hashWithSalt(code, codeSalt);
      await db.collection("orders").doc(result.orderId).update({
        guestConfirmation: {
          codeHash,
          codeSalt,
          attempts: 0,
          confirmed: false,
          locked: false,
        },
      });

      const config = guestSmsGatewayConfig();
      if (!config.userId || !config.apiKey) {
        logger.error("SMSlenz credentials missing for guest order confirmation");
        guestSmsSent = false;
      } else {
        const message =
          `MND Delivery: Order ${result.trackingNumber} confirmed from ${storeName}. ` +
          `Give code ${code} to the rider when your order arrives.`;
        const sent = await sendSmslenzSms(config, resolvedCustomer.phoneE164, message);
        guestSmsSent = sent.ok;
        if (!sent.ok) {
          logger.error("Guest order confirmation SMS failed", {
            orderId: result.orderId,
            error: sent.error,
          });
        }
      }
    }

    return {...result, guestSmsSent};
  },
);

/**
 * Assigned rider completes an actual-trip delivery: finalize fee from path KM,
 * write amountDueFromCustomer, then set status=delivered (earnings trigger runs).
 */
export const completeDeliveryOrder = onCall(
  {region: "asia-south1"},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in to complete delivery.");
    }
    const riderUid = request.auth.uid;
    const orderId = String(request.data?.orderId ?? "").trim();
    if (!orderId) {
      throw new HttpsError("invalid-argument", "orderId is required.");
    }

    let traveledKm = Number(request.data?.traveledKm);
    if (!Number.isFinite(traveledKm)) {
      throw new HttpsError("invalid-argument", "traveledKm is required.");
    }
    traveledKm = Math.min(500, Math.max(0, traveledKm));
    traveledKm = roundTraveledKm(traveledKm);

    const db = getFirestore();
    const orderRef = db.collection("orders").doc(orderId);

    // Guest orders (no MND account) need the SMS'd 4-digit code from the
    // customer before delivery can be marked complete. Runs as its own
    // transaction: a wrong-code attempt must persist (attempt count) even
    // though the overall check fails, and a thrown error inside
    // runTransaction discards all writes from that attempt — so this
    // transaction always *returns* a result instead of throwing on a
    // mismatch, and the caller throws afterward based on that result.
    const verify = await db.runTransaction(async (tx) => {
      const snap = await tx.get(orderRef);
      if (!snap.exists) {
        throw new HttpsError("not-found", "Order not found.");
      }
      const data = snap.data() ?? {};
      const assigned = String(data.riderId ?? data.assignedRiderId ?? "").trim();
      if (!assigned || assigned !== riderUid) {
        throw new HttpsError(
          "permission-denied",
          "Only the assigned rider can complete this delivery.",
        );
      }
      if (data.isGuestCustomer !== true) {
        return {ok: true} as const;
      }
      const gc = (data.guestConfirmation ?? {}) as Record<string, unknown>;
      if (gc.confirmed === true) {
        return {ok: true} as const;
      }
      const codeHash = String(gc.codeHash ?? "");
      const codeSalt = String(gc.codeSalt ?? "");
      if (!codeHash || !codeSalt) {
        throw new HttpsError(
          "failed-precondition",
          "Guest verification was not set up for this order. Contact support.",
        );
      }
      const attempts = Number(gc.attempts ?? 0);
      if (gc.locked === true || attempts >= GUEST_CODE_MAX_ATTEMPTS) {
        return {ok: false, reason: "locked"} as const;
      }
      const codeRaw = String(request.data?.confirmationCode ?? "").trim();
      if (!/^\d{4}$/.test(codeRaw)) {
        return {ok: false, reason: "invalid"} as const;
      }
      const candidate = hashWithSalt(codeRaw, codeSalt);
      if (!safeEqualHex(candidate, codeHash)) {
        const nextAttempts = attempts + 1;
        const patch: Record<string, unknown> = {
          "guestConfirmation.attempts": nextAttempts,
        };
        if (nextAttempts >= GUEST_CODE_MAX_ATTEMPTS) {
          patch["guestConfirmation.locked"] = true;
        }
        tx.update(orderRef, patch);
        return {
          ok: false,
          reason: nextAttempts >= GUEST_CODE_MAX_ATTEMPTS ? "locked" : "mismatch",
        } as const;
      }
      tx.update(orderRef, {"guestConfirmation.confirmed": true});
      return {ok: true} as const;
    });

    if (!verify.ok) {
      if (verify.reason === "locked") {
        throw new HttpsError(
          "resource-exhausted",
          "Too many incorrect codes. This order is flagged for admin review.",
        );
      }
      if (verify.reason === "invalid") {
        throw new HttpsError(
          "invalid-argument",
          "Enter the 4-digit code the customer received by SMS.",
        );
      }
      throw new HttpsError(
        "permission-denied",
        "Incorrect code. Ask the customer to check their SMS and try again.",
      );
    }

    const platformFees = await loadPlatformFeeConfig();
    const result = await db.runTransaction(async (tx) => {
      const snap = await tx.get(orderRef);
      if (!snap.exists) {
        throw new HttpsError("not-found", "Order not found.");
      }
      const data = snap.data() ?? {};
      const status = String(data.status ?? "").trim().toLowerCase();
      const allowed = new Set([
        "out_for_delivery",
        "picked_up",
        "on_the_way",
      ]);
      if (!allowed.has(status)) {
        throw new HttpsError(
          "failed-precondition",
          `Order cannot be completed from status "${status}".`,
        );
      }

      const assigned = String(data.riderId ?? data.assignedRiderId ?? "").trim();
      if (!assigned || assigned !== riderUid) {
        throw new HttpsError(
          "permission-denied",
          "Only the assigned rider can complete this delivery.",
        );
      }

      const mode = String(data.deliveryFeeMode ?? "").trim();
      if (mode !== "actual_trip") {
        throw new HttpsError(
          "failed-precondition",
          "This order does not use trip-distance delivery fees.",
        );
      }

      const subtotal = Math.max(0, Math.floor(Number(data.subtotal ?? 0)));
      const discount = Math.max(0, Math.floor(Number(data.discount ?? 0)));
      const productsPaid = data.productsPaid === true;

      // traveledKm comes straight from the rider's client with no GPS trail
      // to check it against — sanity-bound it against the known
      // pickup→dropoff straight-line distance so a rider can't wildly
      // over- or under-report it to skew the fee/cash they collect.
      const pickupLat = Number(data.pickupLatitude);
      const pickupLng = Number(data.pickupLongitude);
      const dropLat = Number(data.dropoffLatitude);
      const dropLng = Number(data.dropoffLongitude);
      const hasCoords = [pickupLat, pickupLng, dropLat, dropLng].every(
        (n) => Number.isFinite(n),
      );
      const straightKm = hasCoords
        ? haversineKm(pickupLat, pickupLng, dropLat, dropLng)
        : NaN;

      let effectiveKm = traveledKm;
      let traveledKmFlagged = false;
      let traveledKmReported: number | null = null;

      if (hasCoords && Number.isFinite(straightKm) && straightKm > 0.01) {
        if (traveledKm <= 0) {
          // No usable path length from the client — estimate from the
          // known straight-line distance instead of the generic flat
          // fallback, which otherwise overcharges short trips.
          traveledKmReported = traveledKm;
          effectiveKm = roundTraveledKm(straightKm);
          traveledKmFlagged = true;
        } else {
          const clamped = clampTraveledKmToPlausibleRange(
            traveledKm,
            straightKm,
          );
          if (clamped.flagged) {
            traveledKmReported = traveledKm;
            effectiveKm = clamped.km;
            traveledKmFlagged = true;
          }
        }
      }

      // Read the service charge fixed at order creation; recompute as a
      // fallback for orders created before this field existed.
      const serviceCharge = Math.max(
        0,
        Math.floor(
          Number(
            data.serviceCharge ??
              computeServiceChargeLkr(subtotal, platformFees.serviceChargePercent),
          ),
        ),
      );

      const deliveryFee = feeLkrForActualTripKm(effectiveKm, platformFees.delivery);
      const total = Math.max(0, subtotal - discount + deliveryFee + serviceCharge);
      // The rider still collects the delivery fee + service charge even
      // when the customer already paid the shop directly for products.
      const amountDueFromCustomer = productsPaid
        ? deliveryFee + serviceCharge
        : Math.max(0, subtotal - discount + deliveryFee + serviceCharge);
      const productCashLkr = productsPaid
        ? 0
        : Math.max(0, subtotal - discount);

      const patch: Record<string, unknown> = {
        traveledKm: effectiveKm,
        deliveryFee,
        serviceCharge,
        total,
        amountDueFromCustomer,
        productsPaid,
        productCashLkr,
        productCashStatus: productsPaid ? "none" : "owed",
        status: "delivered",
        deliveredAt: FieldValue.serverTimestamp(),
      };
      if (!productsPaid) {
        patch.productCashRiderId = riderUid;
      }
      if (traveledKmFlagged) {
        patch.traveledKmReported = traveledKmReported;
        patch.traveledKmFlagged = true;
        patch.traveledKmFlaggedAt = FieldValue.serverTimestamp();
      }

      tx.update(orderRef, patch);

      return {
        orderId,
        traveledKm: effectiveKm,
        deliveryFee,
        subtotal,
        discount,
        serviceCharge,
        total,
        amountDueFromCustomer,
        productsPaid,
        productCashLkr,
        productCashStatus: productsPaid ? "none" : "owed",
      };
    });

    return result;
  },
);

/**
 * Lets a vendor call the rider assigned to one of their orders. Rider docs
 * are otherwise locked to self/admin (PII — phone, NIC, doc URLs), so this
 * returns only {name, phone} for a rider actually assigned to an order that
 * belongs to the calling vendor's store.
 */
export const getVendorOrderRiderContact = onCall(
  {region: "asia-south1"},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in to view rider contact.");
    }
    const {vendorId} = await resolveCallerVendorStore(request.auth.uid);
    const orderId = String(request.data?.orderId ?? "").trim();
    if (!orderId) {
      throw new HttpsError("invalid-argument", "orderId is required.");
    }

    const db = getFirestore();
    const orderSnap = await db.collection("orders").doc(orderId).get();
    if (!orderSnap.exists) {
      throw new HttpsError("not-found", "Order not found.");
    }
    const order = orderSnap.data()!;
    const orderVendorId = String(
      order.vendorId ?? order.vendorStoreId ?? "",
    ).trim();
    if (orderVendorId !== vendorId) {
      throw new HttpsError(
        "permission-denied",
        "This order does not belong to your store.",
      );
    }

    const riderId = String(order.riderId ?? order.assignedRiderId ?? "").trim();
    if (!riderId) {
      throw new HttpsError(
        "failed-precondition",
        "No rider is assigned to this order yet.",
      );
    }

    const riderSnap = await db.collection("riders").doc(riderId).get();
    if (!riderSnap.exists) {
      throw new HttpsError("not-found", "Rider profile not found.");
    }
    const rider = riderSnap.data()!;
    const name =
      String(rider.fullName ?? rider.name ?? "").trim().slice(0, 120) ||
      "Rider";
    const phone = String(rider.phone ?? "").trim();
    if (!phone) {
      throw new HttpsError("not-found", "Rider phone not available.");
    }

    return {name, phone};
  },
);
