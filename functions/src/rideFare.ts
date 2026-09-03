import {createHash, randomUUID} from "crypto";
import {FieldValue, getFirestore, Timestamp} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";

export type RideVehicleType = "wheel" | "bike" | "car";

export type FareRates = {
  baseLkr: number;
  perKmLkr: number;
  minLkr: number;
  /** Surcharge per intermediate stop. Defaults to 0 for older configs. */
  perStopLkr: number;
};
export type FareTable = Record<RideVehicleType, FareRates>;

const EARTH_RADIUS_KM = 6371.0088;

/** Max intermediate stops a customer can add between pickup and drop-off. */
export const MAX_RIDE_STOPS = 2;

/** Built-in defaults when `ride_fare_config/rates` is missing. */
export const DEFAULT_FARE_TABLE: FareTable = {
  wheel: {baseLkr: 150, perKmLkr: 40, minLkr: 250, perStopLkr: 50},
  bike: {baseLkr: 100, perKmLkr: 25, minLkr: 150, perStopLkr: 50},
  car: {baseLkr: 200, perKmLkr: 50, minLkr: 400, perStopLkr: 100},
};

const FARE_CACHE_TTL_MS = 60 * 1000;
const QUOTE_TTL_MS = 15 * 60 * 1000;

let fareCache: {table: FareTable; loadedAt: number} | null = null;

function parseFareRates(raw: unknown): FareRates | null {
  const m = (raw ?? {}) as Record<string, unknown>;
  const baseLkr = Math.floor(Number(m.baseLkr));
  const perKmLkr = Math.floor(Number(m.perKmLkr));
  const minLkr = Math.floor(Number(m.minLkr));
  // Older configs predate this field — default to 0 rather than rejecting
  // the whole doc, so existing fare quoting isn't broken by this rollout.
  const perStopLkr = m.perStopLkr === undefined ?
    0 :
    Math.floor(Number(m.perStopLkr));
  if (
    !Number.isFinite(baseLkr) ||
    !Number.isFinite(perKmLkr) ||
    !Number.isFinite(minLkr) ||
    !Number.isFinite(perStopLkr) ||
    baseLkr < 0 ||
    perKmLkr < 0 ||
    minLkr < 0 ||
    perStopLkr < 0
  ) {
    return null;
  }
  return {baseLkr, perKmLkr, minLkr, perStopLkr};
}

export function parseFareTable(
  data: Record<string, unknown> | undefined,
): FareTable | null {
  if (!data) {
    return null;
  }
  const bike = parseFareRates(data.bike);
  const wheel = parseFareRates(data.wheel);
  const car = parseFareRates(data.car);
  if (!bike || !wheel || !car) {
    return null;
  }
  return {bike, wheel, car};
}

/** Load admin rates from Firestore (cached ~60s). Falls back to defaults. */
export async function loadFareTable(): Promise<FareTable> {
  const now = Date.now();
  if (fareCache && now - fareCache.loadedAt < FARE_CACHE_TTL_MS) {
    return fareCache.table;
  }
  try {
    const snap = await getFirestore()
      .collection("ride_fare_config")
      .doc("rates")
      .get();
    const parsed = parseFareTable(
      snap.data() as Record<string, unknown> | undefined,
    );
    const table = parsed ?? DEFAULT_FARE_TABLE;
    fareCache = {table, loadedAt: now};
    return table;
  } catch {
    return fareCache?.table ?? DEFAULT_FARE_TABLE;
  }
}

/** Test helper — clear in-memory cache. */
export function clearFareTableCache(): void {
  fareCache = null;
}

export function haversineKm(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number,
): number {
  const toRad = (d: number) => (d * Math.PI) / 180;
  const phi1 = toRad(lat1);
  const phi2 = toRad(lat2);
  const dPhi = toRad(lat2 - lat1);
  const dLambda = toRad(lng2 - lng1);
  const a =
    Math.sin(dPhi / 2) ** 2 +
    Math.cos(phi1) * Math.cos(phi2) * Math.sin(dLambda / 2) ** 2;
  return EARTH_RADIUS_KM * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

export function fareLkrForDistance(
  vehicleType: RideVehicleType,
  distanceKm: number,
  table: FareTable = DEFAULT_FARE_TABLE,
  stopCount = 0,
): number {
  const rates = table[vehicleType];
  if (!rates || !Number.isFinite(distanceKm) || distanceKm < 0) {
    return rates?.minLkr ?? 0;
  }
  const raw =
    rates.baseLkr +
    Math.ceil(distanceKm * rates.perKmLkr) +
    stopCount * rates.perStopLkr;
  return Math.max(rates.minLkr, raw);
}

/** Straight-line distance across consecutive points (pickup, stops…, dropoff). */
export function multiLegKm(
  points: Array<{lat: number; lng: number}>,
): number {
  let total = 0;
  for (let i = 0; i < points.length - 1; i++) {
    total += haversineKm(
      points[i].lat,
      points[i].lng,
      points[i + 1].lat,
      points[i + 1].lng,
    );
  }
  return total;
}

function parsePlace(raw: unknown): {lat: number; lng: number; label: string} {
  const m = (raw ?? {}) as Record<string, unknown>;
  const lat = Number(m.lat);
  const lng = Number(m.lng);
  const label = String(m.label ?? "").trim();
  if (!Number.isFinite(lat) || !Number.isFinite(lng) || !label) {
    throw new HttpsError(
      "invalid-argument",
      "pickup/dropoff need lat, lng, and label.",
    );
  }
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
    throw new HttpsError("invalid-argument", "Invalid coordinates.");
  }
  if (label.length > 240) {
    throw new HttpsError("invalid-argument", "Address label is too long.");
  }
  return {lat, lng, label};
}

function parseStops(
  raw: unknown,
): Array<{lat: number; lng: number; label: string}> {
  if (raw === undefined || raw === null) {
    return [];
  }
  if (!Array.isArray(raw)) {
    throw new HttpsError("invalid-argument", "stops must be a list.");
  }
  if (raw.length > MAX_RIDE_STOPS) {
    throw new HttpsError(
      "invalid-argument",
      `A ride can have at most ${MAX_RIDE_STOPS} stops.`,
    );
  }
  return raw.map((s) => parsePlace(s));
}

function parseVehicle(raw: unknown): RideVehicleType {
  const v = String(raw ?? "").trim().toLowerCase();
  if (v === "wheel" || v === "bike" || v === "car") {
    return v;
  }
  throw new HttpsError(
    "invalid-argument",
    "vehicleType must be wheel, bike, or car.",
  );
}

async function createQuoteDocs(
  customerId: string,
  pickup: {lat: number; lng: number; label: string},
  dropoff: {lat: number; lng: number; label: string},
  vehicleTypes: RideVehicleType[],
  stops: Array<{lat: number; lng: number; label: string}> = [],
): Promise<
  Array<{
    quoteId: string;
    vehicleType: RideVehicleType;
    distanceKm: number;
    fareLkr: number;
    expiresAtMs: number;
    trafficLabel: string;
  }>
> {
  const distanceKm =
    Math.round(multiLegKm([pickup, ...stops, dropoff]) * 10) / 10;
  if (distanceKm < 0.1) {
    throw new HttpsError(
      "invalid-argument",
      "Pickup and drop-off are too close.",
    );
  }

  const fareTable = await loadFareTable();
  const expiresAt = Timestamp.fromMillis(Date.now() + QUOTE_TTL_MS);
  const expiresAtMs = expiresAt.toMillis();
  const db = getFirestore();
  const batch = db.batch();
  const quotes: Array<{
    quoteId: string;
    vehicleType: RideVehicleType;
    distanceKm: number;
    fareLkr: number;
    expiresAtMs: number;
    trafficLabel: string;
  }> = [];

  for (const vehicleType of vehicleTypes) {
    const quoteId = randomUUID();
    const fareLkr = fareLkrForDistance(
      vehicleType,
      distanceKm,
      fareTable,
      stops.length,
    );
    batch.set(db.collection("ride_fare_quotes").doc(quoteId), {
      customerId,
      vehicleType,
      pickup,
      dropoff,
      stops,
      distanceKm,
      fareLkr,
      expiresAt,
      createdAt: FieldValue.serverTimestamp(),
    });
    quotes.push({
      quoteId,
      vehicleType,
      distanceKm,
      fareLkr,
      expiresAtMs,
      trafficLabel: "Normal traffic",
    });
  }

  await batch.commit();
  return quotes;
}

export const quoteRideFare = onCall(
  {region: "asia-south1"},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in to get a fare quote.");
    }

    const vehicleType = parseVehicle(request.data?.vehicleType);
    const pickup = parsePlace(request.data?.pickup);
    const dropoff = parsePlace(request.data?.dropoff);
    const stops = parseStops(request.data?.stops);
    const [quote] = await createQuoteDocs(
      request.auth.uid,
      pickup,
      dropoff,
      [vehicleType],
      stops,
    );
    return quote;
  },
);

/** One round-trip for all vehicle fares (Bike / Wheel / Car). */
export const quoteRideFares = onCall(
  {region: "asia-south1"},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in to get a fare quote.");
    }

    const pickup = parsePlace(request.data?.pickup);
    const dropoff = parsePlace(request.data?.dropoff);
    const stops = parseStops(request.data?.stops);
    const quotes = await createQuoteDocs(
      request.auth.uid,
      pickup,
      dropoff,
      ["bike", "wheel", "car"],
      stops,
    );
    return {quotes};
  },
);

export async function loadValidQuote(
  quoteId: string,
  uid: string,
): Promise<{
  vehicleType: RideVehicleType;
  pickup: {lat: number; lng: number; label: string};
  dropoff: {lat: number; lng: number; label: string};
  stops: Array<{lat: number; lng: number; label: string}>;
  distanceKm: number;
  fareLkr: number;
}> {
  const snap = await getFirestore()
    .collection("ride_fare_quotes")
    .doc(quoteId)
    .get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "Fare quote not found.");
  }
  const data = snap.data()!;
  if (String(data.customerId) !== uid) {
    throw new HttpsError("permission-denied", "This quote is not yours.");
  }
  if (data.usedTripId) {
    throw new HttpsError("failed-precondition", "Fare quote already used.");
  }
  const expiresAt = data.expiresAt as Timestamp | undefined;
  if (!expiresAt || expiresAt.toMillis() < Date.now()) {
    throw new HttpsError("failed-precondition", "Fare quote expired.");
  }
  return {
    vehicleType: parseVehicle(data.vehicleType),
    pickup: parsePlace(data.pickup),
    dropoff: parsePlace(data.dropoff),
    // Older quote docs predate this field — default to no stops.
    stops: Array.isArray(data.stops) ? parseStops(data.stops) : [],
    distanceKm: Number(data.distanceKm),
    fareLkr: Math.floor(Number(data.fareLkr)),
  };
}

/** Shared PayHere merchant config, used by both the ride and order checkouts. */
export function payHereConfig(): {
  merchantId: string;
  merchantSecret: string;
  /**
   * Secret for the "Domain" integration (mnd.lk) — separate from
   * merchantSecret ("Mobile App") because PayHere issues a distinct secret
   * per registered domain/app. Falls back to merchantSecret if unset, so a
   * missing env var degrades to the pre-split behavior rather than throwing.
   */
  domainMerchantSecret: string;
  sandbox: boolean;
  returnUrl: string;
  cancelUrl: string;
  notifyUrl: string;
  checkoutPageUrl: string;
} {
  const merchantId = (process.env.PAYHERE_MERCHANT_ID ?? "").trim();
  const merchantSecret = (process.env.PAYHERE_MERCHANT_SECRET ?? "").trim();
  const domainMerchantSecret =
    (process.env.PAYHERE_DOMAIN_MERCHANT_SECRET ?? "").trim() ||
    merchantSecret;
  const mode = (process.env.PAYHERE_MODE ?? "sandbox").trim().toLowerCase();
  const returnUrl =
    (process.env.PAYHERE_RETURN_URL ?? "").trim() ||
    "https://mnd-masterndelivery.web.app/rides/pay-return";
  const cancelUrl =
    (process.env.PAYHERE_CANCEL_URL ?? "").trim() ||
    "https://mnd-masterndelivery.web.app/rides/pay-cancel";
  const notifyUrl =
    (process.env.PAYHERE_NOTIFY_URL ?? "").trim() ||
    "https://asia-south1-mnd-masterndelivery.cloudfunctions.net/payHereNotify";
  // Server-hosted self-submitting checkout form. Every caller (mnd.lk web,
  // and all mobile apps' in-app WebViews) loads this same URL, so the POST
  // to PayHere always carries this one domain's Origin/Referer — PayHere
  // only needs a single "Domain" integration authorized for it, instead of
  // one authorization per calling app.
  const checkoutPageUrl =
    (process.env.PAYHERE_CHECKOUT_PAGE_URL ?? "").trim() ||
    "https://mnd.lk/payhere-checkout";

  if (!merchantId || !merchantSecret) {
    throw new HttpsError(
      "failed-precondition",
      "PayHere is not configured (PAYHERE_MERCHANT_ID / PAYHERE_MERCHANT_SECRET).",
    );
  }

  return {
    merchantId,
    merchantSecret,
    domainMerchantSecret,
    sandbox: mode !== "live",
    returnUrl,
    cancelUrl,
    notifyUrl,
    checkoutPageUrl,
  };
}

/** PayHere checkout hash: MD5(merchant_id + order_id + amount + currency + MD5(merchant_secret)). */
export function payHereCheckoutHash(
  merchantId: string,
  orderId: string,
  amount: string,
  currency: string,
  merchantSecret: string,
): string {
  const secretHash = createHash("md5")
    .update(merchantSecret)
    .digest("hex")
    .toUpperCase();
  return createHash("md5")
    .update(merchantId + orderId + amount + currency + secretHash)
    .digest("hex")
    .toUpperCase();
}

export function payHereNotifyHash(
  merchantId: string,
  orderId: string,
  amount: string,
  currency: string,
  statusCode: string,
  merchantSecret: string,
): string {
  const secretHash = createHash("md5")
    .update(merchantSecret)
    .digest("hex")
    .toUpperCase();
  return createHash("md5")
    .update(merchantId + orderId + amount + currency + statusCode + secretHash)
    .digest("hex")
    .toUpperCase();
}
