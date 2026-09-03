import {createHash, randomBytes, timingSafeEqual} from "crypto";
import {getAuth} from "firebase-admin/auth";
import {FieldValue, getFirestore, Timestamp, type DocumentData} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {defineSecret, defineString} from "firebase-functions/params";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {normalizeCustomerPhoneE164} from "./phoneNormalize";
import {sendSmslenzSms} from "./smslenz";

const REGION = "asia-south1";
const OTP_TTL_MS = 10 * 60 * 1000;
const MAX_OTP_ATTEMPTS = 5;
const MIN_RESEND_INTERVAL_MS = 45 * 1000;
const MAX_REQUESTS_PER_HOUR = 8;
const COLLECTION = "phoneOtps";

const smslenzApiKey = defineSecret("SMSLENZ_API_KEY");
const smslenzUserId = defineString("SMSLENZ_USER_ID", {
  default: "",
  description: "SMSlenz dashboard user_id",
});
const smslenzSenderId = defineString("SMSLENZ_SENDER_ID", {
  default: "MN Delivery",
  description: "Approved SMSlenz sender_id",
});

type OtpDoc = {
  phoneE164: string;
  sessionId: string;
  otpHash: string;
  otpSalt: string;
  otpExpiresAt: Timestamp;
  otpAttempts: number;
  requestCount: number;
  windowStartedAt: Timestamp;
  lastSentAt: Timestamp;
  purpose?: string;
};

function phoneDocId(e164: string): string {
  return createHash("sha256").update(e164).digest("hex");
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

function generateOtp(): string {
  const n = randomBytes(3).readUIntBE(0, 3) % 1_000_000;
  return n.toString().padStart(6, "0");
}

function generateSessionId(): string {
  return randomBytes(24).toString("hex");
}

function requirePhoneE164(raw: unknown): string {
  const normalized = normalizeCustomerPhoneE164(raw);
  if (!normalized.ok) {
    throw new HttpsError("invalid-argument", normalized.error);
  }
  return normalized.e164;
}

function readPurpose(raw: unknown): string {
  if (typeof raw !== "string") {
    return "login";
  }
  const purpose = raw.trim().toLowerCase();
  if (!purpose || purpose.length > 32) {
    return "login";
  }
  return purpose;
}

function isCompleteRiderDoc(data: DocumentData | undefined): boolean {
  if (!data) {
    return false;
  }
  if (data.registrationComplete === true) {
    return true;
  }
  // Legacy docs may omit the flag.
  const fullName = typeof data.fullName === "string" ? data.fullName.trim() : "";
  const phone = typeof data.phone === "string" ? data.phone.trim() : "";
  const nic = typeof data.nicNumber === "string" ? data.nicNumber.trim() : "";
  const vehicle =
    typeof data.vehicleNumber === "string" ? data.vehicleNumber.trim() : "";
  const city = typeof data.city === "string" ? data.city.trim() : "";
  return (
    fullName.length >= 2 &&
    phone.length > 0 &&
    nic.length > 0 &&
    vehicle.length >= 3 &&
    city.length >= 2
  );
}

/**
 * Sign-in OTP is only for phones that already have a complete rider profile.
 */
async function assertRegisteredRiderForLogin(e164: string): Promise<void> {
  const db = getFirestore();
  const ridersSnap = await db
    .collection("riders")
    .where("phone", "==", e164)
    .limit(1)
    .get();
  if (ridersSnap.empty || !isCompleteRiderDoc(ridersSnap.docs[0].data())) {
    throw new HttpsError("not-found", "Still not registered");
  }
}

/**
 * Register OTP must not be issued for a phone that already has a complete rider.
 */
async function assertPhoneAvailableForRegister(e164: string): Promise<void> {
  const db = getFirestore();
  const ridersSnap = await db
    .collection("riders")
    .where("phone", "==", e164)
    .limit(1)
    .get();
  if (!ridersSnap.empty && isCompleteRiderDoc(ridersSnap.docs[0].data())) {
    throw new HttpsError(
      "already-exists",
      "This number is already registered. Sign in instead.",
    );
  }
}

function gatewayConfig(): {userId: string; apiKey: string; senderId: string} {
  return {
    userId: (process.env.SMSLENZ_USER_ID || smslenzUserId.value() || "").trim(),
    apiKey: (process.env.SMSLENZ_API_KEY || smslenzApiKey.value() || "").trim(),
    senderId: (
      process.env.SMSLENZ_SENDER_ID ||
      smslenzSenderId.value() ||
      "MN Delivery"
    ).trim(),
  };
}

async function findOrCreatePhoneUser(e164: string): Promise<string> {
  const auth = getAuth();
  try {
    const existing = await auth.getUserByPhoneNumber(e164);
    return existing.uid;
  } catch (e: unknown) {
    const code = (e as {code?: string}).code;
    if (code !== "auth/user-not-found") {
      logger.error("getUserByPhoneNumber failed", e);
      throw new HttpsError("internal", "Could not verify phone account.");
    }
  }

  // Legacy riders signed up with synthetic email before phone was on Auth.
  const digits = e164.replace(/\D/g, "");
  const syntheticEmail = `rider.${digits}@riders.mnd.app`;
  try {
    const byEmail = await auth.getUserByEmail(syntheticEmail);
    await auth.updateUser(byEmail.uid, {phoneNumber: e164});
    logger.info("Linked phone onto legacy rider email Auth user", {
      uid: byEmail.uid,
    });
    return byEmail.uid;
  } catch (e: unknown) {
    const code = (e as {code?: string}).code;
    if (code !== "auth/user-not-found") {
      logger.warn("Legacy email Auth lookup/link failed", {code, e});
    }
  }

  // Profile exists under an Auth uid that never had phone/email linked.
  try {
    const db = getFirestore();
    const ridersSnap = await db
      .collection("riders")
      .where("phone", "==", e164)
      .limit(1)
      .get();
    if (!ridersSnap.empty) {
      const riderUid = ridersSnap.docs[0].id;
      try {
        await auth.getUser(riderUid);
        await auth.updateUser(riderUid, {phoneNumber: e164});
        logger.info("Linked phone onto Auth user from riders/{uid}", {
          uid: riderUid,
        });
        return riderUid;
      } catch (inner: unknown) {
        logger.warn("Rider doc uid is not a usable Auth user", {
          riderUid,
          inner,
        });
      }
    }
  } catch (e) {
    logger.warn("riders phone lookup failed", e);
  }

  try {
    const created = await auth.createUser({phoneNumber: e164});
    return created.uid;
  } catch (e: unknown) {
    // Race: another request created the same phone.
    const code = (e as {code?: string}).code;
    if (code === "auth/phone-number-already-exists") {
      const again = await auth.getUserByPhoneNumber(e164);
      return again.uid;
    }
    logger.error("createUser with phone failed", e);
    throw new HttpsError("internal", "Could not create phone account.");
  }
}

/**
 * Step 1: phone → generate OTP, send via SMSlenz, store hash in Firestore.
 */
export const requestPhoneOtp = onCall(
  {
    region: REGION,
    invoker: "public",
    secrets: [smslenzApiKey],
    timeoutSeconds: 30,
  },
  async (request) => {
    const e164 = requirePhoneE164(request.data?.phone);
    const purpose = readPurpose(request.data?.purpose);

    // Sign-in: only send OTP when this phone already has a complete rider profile.
    if (purpose === "rider_login") {
      await assertRegisteredRiderForLogin(e164);
    }
    if (purpose === "rider_register") {
      await assertPhoneAvailableForRegister(e164);
    }

    const db = getFirestore();
    const ref = db.collection(COLLECTION).doc(phoneDocId(e164));
    const now = Date.now();

    const snap = await ref.get();
    const existing = snap.data() as OtpDoc | undefined;

    if (existing?.lastSentAt) {
      const last = existing.lastSentAt.toMillis();
      if (now - last < MIN_RESEND_INTERVAL_MS) {
        throw new HttpsError(
          "resource-exhausted",
          "Please wait a moment before requesting another code.",
        );
      }
    }

    let requestCount = 1;
    let windowStartedAt = Timestamp.fromMillis(now);
    if (existing?.windowStartedAt) {
      const windowStart = existing.windowStartedAt.toMillis();
      if (now - windowStart < 60 * 60 * 1000) {
        requestCount = (existing.requestCount ?? 0) + 1;
        windowStartedAt = existing.windowStartedAt;
        if (requestCount > MAX_REQUESTS_PER_HOUR) {
          throw new HttpsError(
            "resource-exhausted",
            "Too many OTP requests. Try again later.",
          );
        }
      }
    }

    const otp = generateOtp();
    const sessionId = generateSessionId();
    const otpSalt = randomBytes(16).toString("hex");
    const otpHash = hashWithSalt(otp, otpSalt);

    const config = gatewayConfig();
    if (!config.userId || !config.apiKey) {
      logger.error("SMSlenz credentials missing");
      throw new HttpsError(
        "failed-precondition",
        "SMS gateway is not configured. Contact support.",
      );
    }

    const message =
      `Your MND verification code is ${otp}. ` +
      "Valid for 10 minutes. Do not share this code.";

    const sent = await sendSmslenzSms(config, e164, message);
    if (!sent.ok) {
      throw new HttpsError(
        "unavailable",
        "Could not send verification SMS. Please try again.",
      );
    }

    await ref.set(
      {
        phoneE164: e164,
        sessionId,
        otpHash,
        otpSalt,
        otpExpiresAt: Timestamp.fromMillis(now + OTP_TTL_MS),
        otpAttempts: 0,
        requestCount,
        windowStartedAt,
        lastSentAt: Timestamp.fromMillis(now),
        purpose,
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

    logger.info("Phone OTP sent via SMSlenz", {
      phoneHash: phoneDocId(e164),
      purpose,
    });

    return {
      ok: true,
      sessionId,
      expiresInSec: Math.floor(OTP_TTL_MS / 1000),
    };
  },
);

/**
 * Step 2: phone + OTP (+ sessionId) → Firebase custom token.
 */
export const verifyPhoneOtp = onCall(
  {
    region: REGION,
    invoker: "public",
    timeoutSeconds: 30,
  },
  async (request) => {
    const e164 = requirePhoneE164(request.data?.phone);
    const otpRaw = request.data?.otp;
    if (typeof otpRaw !== "string" || !/^\d{6}$/.test(otpRaw.trim())) {
      throw new HttpsError("invalid-argument", "Enter the 6-digit code");
    }
    const otp = otpRaw.trim();

    const sessionRaw = request.data?.sessionId;
    const sessionId =
      typeof sessionRaw === "string" && sessionRaw.trim().length >= 16
        ? sessionRaw.trim()
        : null;

    const db = getFirestore();
    const ref = db.collection(COLLECTION).doc(phoneDocId(e164));
    const snap = await ref.get();
    if (!snap.exists) {
      throw new HttpsError(
        "not-found",
        "Invalid or expired code. Request a new one.",
      );
    }

    const data = snap.data() as OtpDoc;
    const now = Date.now();

    if (!data.otpHash || !data.otpSalt || !data.otpExpiresAt || !data.sessionId) {
      throw new HttpsError("failed-precondition", "Request a new code first.");
    }
    if (data.otpExpiresAt.toMillis() < now) {
      throw new HttpsError(
        "deadline-exceeded",
        "Code expired. Request a new one.",
      );
    }
    if ((data.otpAttempts ?? 0) >= MAX_OTP_ATTEMPTS) {
      throw new HttpsError(
        "resource-exhausted",
        "Too many attempts. Request a new code.",
      );
    }
    if (sessionId && sessionId !== data.sessionId) {
      throw new HttpsError(
        "failed-precondition",
        "Session expired. Request a new code.",
      );
    }

    const candidate = hashWithSalt(otp, data.otpSalt);
    const match = safeEqualHex(candidate, data.otpHash);
    if (!match) {
      await ref.update({
        otpAttempts: FieldValue.increment(1),
        updatedAt: FieldValue.serverTimestamp(),
      });
      throw new HttpsError("permission-denied", "Incorrect code. Try again.");
    }

    const uid = await findOrCreatePhoneUser(e164);

    // Ensure Auth profile still has this phone (custom-token users keep it).
    try {
      const user = await getAuth().getUser(uid);
      if (user.phoneNumber !== e164) {
        await getAuth().updateUser(uid, {phoneNumber: e164});
      }
    } catch (e) {
      logger.warn("Could not refresh phoneNumber on Auth user", e);
    }

    let customToken: string;
    try {
      customToken = await getAuth().createCustomToken(uid, {
        phoneVerified: true,
        // Bound to the specific number this OTP proved, so security rules
        // can't be satisfied by a *different* phone claimed in a document.
        verifiedPhone: e164,
      });
    } catch (e) {
      logger.error("createCustomToken failed", e);
      throw new HttpsError("internal", "Could not complete sign-in. Try again.");
    }

    // Only burn the OTP after we can actually sign the user in.
    await ref.delete();

    return {
      ok: true,
      customToken,
      uid,
      phoneNumber: e164,
    };
  },
);
