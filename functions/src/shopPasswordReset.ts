import {createHash, randomBytes, timingSafeEqual} from "crypto";
import {getAuth} from "firebase-admin/auth";
import {FieldValue, getFirestore, Timestamp} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {defineBoolean} from "firebase-functions/params";
import {HttpsError, onCall} from "firebase-functions/v2/https";

const REGION = "asia-south1";
const OTP_TTL_MS = 10 * 60 * 1000;
const RESET_TOKEN_TTL_MS = 15 * 60 * 1000;
const MAX_OTP_ATTEMPTS = 5;
const MIN_RESEND_INTERVAL_MS = 45 * 1000;
const MAX_REQUESTS_PER_HOUR = 5;
const COLLECTION = "shopPasswordResets";

/** QA only: return OTP in callable response. Keep false in production. */
const shopPasswordResetDebug = defineBoolean("SHOP_PASSWORD_RESET_DEBUG", {
  default: false,
  description:
    "When true, requestShopPasswordResetOtp returns debugOtp (emulator / explicit QA only).",
});

type ResetDoc = {
  email: string;
  uid: string;
  otpHash: string;
  otpSalt: string;
  otpExpiresAt: Timestamp;
  otpAttempts: number;
  requestCount: number;
  windowStartedAt: Timestamp;
  lastSentAt: Timestamp;
  resetTokenHash?: string;
  resetTokenSalt?: string;
  resetTokenExpiresAt?: Timestamp;
  verifiedAt?: Timestamp;
};

function normalizeEmail(raw: unknown): string {
  if (typeof raw !== "string") {
    throw new HttpsError("invalid-argument", "Email is required");
  }
  const email = raw.trim().toLowerCase();
  if (!email.includes("@") || email.length < 5 || email.length > 200) {
    throw new HttpsError("invalid-argument", "Enter a valid email address");
  }
  return email;
}

function emailDocId(email: string): string {
  return createHash("sha256").update(email).digest("hex");
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
  // 6-digit, never padded with leading zeros lost as string.
  const n = randomBytes(3).readUIntBE(0, 3) % 1_000_000;
  return n.toString().padStart(6, "0");
}

function generateToken(): string {
  return randomBytes(32).toString("hex");
}

function isDebugOtpEnabled(): boolean {
  return (
    process.env.FUNCTIONS_EMULATOR === "true" ||
    process.env.SHOP_PASSWORD_RESET_DEBUG === "1" ||
    shopPasswordResetDebug.value()
  );
}

async function queueOtpEmail(email: string, otp: string): Promise<void> {
  const db = getFirestore();
  await db.collection("mail").add({
    to: [email],
    message: {
      subject: "MND Shop — password reset code",
      text:
        `Your MND Shop password reset code is ${otp}.\n\n` +
        "This code expires in 10 minutes. If you did not request a reset, ignore this email.",
      html:
        `<p>Your MND Shop password reset code is:</p>` +
        `<p style="font-size:28px;font-weight:700;letter-spacing:6px;">${otp}</p>` +
        `<p>This code expires in 10 minutes. If you did not request a reset, ignore this email.</p>`,
    },
    createdAt: FieldValue.serverTimestamp(),
    type: "shop_password_reset_otp",
  });
}

/**
 * Step 1: email → generate OTP, queue email (Firestore `mail` + Trigger Email extension).
 * Always returns success-shaped response so account existence is not leaked.
 */
export const requestShopPasswordResetOtp = onCall(
  {region: REGION, invoker: "public"},
  async (request) => {
    const email = normalizeEmail(request.data?.email);
    const auth = getAuth();
    const db = getFirestore();
    const docId = emailDocId(email);
    const ref = db.collection(COLLECTION).doc(docId);
    const now = Date.now();

    let uid: string | null = null;
    try {
      const user = await auth.getUserByEmail(email);
      uid = user.uid;
    } catch (e: unknown) {
      const code = (e as {code?: string}).code;
      if (code !== "auth/user-not-found") {
        logger.error("requestShopPasswordResetOtp getUserByEmail failed", e);
        throw new HttpsError("internal", "Could not start password reset");
      }
    }

    // Do not reveal whether the email exists.
    if (!uid) {
      return {
        ok: true,
        message: "If an account exists for that email, a code was sent.",
      };
    }

    const snap = await ref.get();
    const existing = snap.data() as ResetDoc | undefined;

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
            "Too many reset requests. Try again later.",
          );
        }
      }
    }

    const otp = generateOtp();
    const otpSalt = randomBytes(16).toString("hex");
    const otpHash = hashWithSalt(otp, otpSalt);

    await ref.set(
      {
        email,
        uid,
        otpHash,
        otpSalt,
        otpExpiresAt: Timestamp.fromMillis(now + OTP_TTL_MS),
        otpAttempts: 0,
        requestCount,
        windowStartedAt,
        lastSentAt: Timestamp.fromMillis(now),
        resetTokenHash: FieldValue.delete(),
        resetTokenExpiresAt: FieldValue.delete(),
        verifiedAt: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

    try {
      await queueOtpEmail(email, otp);
    } catch (e) {
      logger.error("Failed to queue OTP email", e);
      // Still allow debug path; production needs Trigger Email / mail worker.
    }

    logger.info("Shop password reset OTP queued", {
      emailHash: docId,
      debug: isDebugOtpEnabled(),
    });

    const response: {
      ok: boolean;
      message: string;
      debugOtp?: string;
    } = {
      ok: true,
      message: "If an account exists for that email, a code was sent.",
    };

    if (isDebugOtpEnabled()) {
      response.debugOtp = otp;
    }

    return response;
  },
);

/**
 * Step 2: verify OTP → short-lived reset token for setting a new password.
 */
export const verifyShopPasswordResetOtp = onCall(
  {region: REGION, invoker: "public"},
  async (request) => {
    const email = normalizeEmail(request.data?.email);
    const otpRaw = request.data?.otp;
    if (typeof otpRaw !== "string" || !/^\d{6}$/.test(otpRaw.trim())) {
      throw new HttpsError("invalid-argument", "Enter the 6-digit code");
    }
    const otp = otpRaw.trim();

    const db = getFirestore();
    const ref = db.collection(COLLECTION).doc(emailDocId(email));
    const snap = await ref.get();
    if (!snap.exists) {
      throw new HttpsError("not-found", "Invalid or expired code. Request a new one.");
    }

    const data = snap.data() as ResetDoc;
    const now = Date.now();

    if (!data.otpHash || !data.otpSalt || !data.otpExpiresAt) {
      throw new HttpsError("failed-precondition", "Request a new code first.");
    }
    if (data.otpExpiresAt.toMillis() < now) {
      throw new HttpsError("deadline-exceeded", "Code expired. Request a new one.");
    }
    if ((data.otpAttempts ?? 0) >= MAX_OTP_ATTEMPTS) {
      throw new HttpsError(
        "resource-exhausted",
        "Too many attempts. Request a new code.",
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

    const resetToken = generateToken();
    const tokenSalt = randomBytes(16).toString("hex");
    const resetTokenHash = hashWithSalt(resetToken, tokenSalt);

    await ref.update({
      otpHash: FieldValue.delete(),
      otpSalt: FieldValue.delete(),
      otpExpiresAt: FieldValue.delete(),
      otpAttempts: 0,
      resetTokenHash,
      resetTokenSalt: tokenSalt,
      resetTokenExpiresAt: Timestamp.fromMillis(now + RESET_TOKEN_TTL_MS),
      verifiedAt: Timestamp.fromMillis(now),
      updatedAt: FieldValue.serverTimestamp(),
    });

    return {ok: true, resetToken};
  },
);

/**
 * Step 3: reset token + new password → Admin SDK updateUser.
 */
export const confirmShopPasswordReset = onCall(
  {region: REGION, invoker: "public"},
  async (request) => {
    const email = normalizeEmail(request.data?.email);
    const resetToken = request.data?.resetToken;
    const newPassword = request.data?.newPassword;

    if (typeof resetToken !== "string" || resetToken.length < 32) {
      throw new HttpsError("invalid-argument", "Invalid reset session");
    }
    if (typeof newPassword !== "string" || newPassword.length < 6) {
      throw new HttpsError(
        "invalid-argument",
        "Password must be at least 6 characters",
      );
    }
    if (newPassword.length > 128) {
      throw new HttpsError("invalid-argument", "Password is too long");
    }

    const db = getFirestore();
    const ref = db.collection(COLLECTION).doc(emailDocId(email));
    const snap = await ref.get();
    if (!snap.exists) {
      throw new HttpsError("not-found", "Reset session expired. Start again.");
    }

    const data = snap.data() as ResetDoc;
    const now = Date.now();

    if (
      !data.uid ||
      !data.resetTokenHash ||
      !data.resetTokenSalt ||
      !data.resetTokenExpiresAt
    ) {
      throw new HttpsError(
        "failed-precondition",
        "Verify your code before setting a new password.",
      );
    }
    if (data.resetTokenExpiresAt.toMillis() < now) {
      throw new HttpsError("deadline-exceeded", "Reset session expired. Start again.");
    }

    const candidate = hashWithSalt(resetToken, data.resetTokenSalt);
    if (!safeEqualHex(candidate, data.resetTokenHash)) {
      throw new HttpsError("permission-denied", "Invalid reset session. Start again.");
    }

    try {
      await getAuth().updateUser(data.uid, {password: newPassword});
    } catch (e) {
      logger.error("confirmShopPasswordReset updateUser failed", e);
      throw new HttpsError("internal", "Could not update password. Try again.");
    }

    await ref.delete();

    return {ok: true};
  },
);
