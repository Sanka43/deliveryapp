import {getAuth} from "firebase-admin/auth";
import {onCall, HttpsError} from "firebase-functions/v2/https";

const LEGACY_PASSWORD = "MndRiderTempOtp123456!";

function riderAuthEmail(e164Phone: string): string {
  const digits = e164Phone.replace(/\D/g, "");
  if (digits.length < 9) {
    throw new HttpsError("invalid-argument", "Invalid phone number");
  }
  return `rider.${digits}@riders.mnd.app`;
}

/**
 * Dev/QA only: resets the synthetic rider email password to the legacy OTP
 * secret and returns a custom token so the app can sign in after Dev OTP 123456.
 */
export const devRiderOtpSignIn = onCall(
  {invoker: "public"},
  async (request) => {
    const e164Phone = request.data?.e164Phone;
    if (typeof e164Phone !== "string" || e164Phone.trim().length < 10) {
      throw new HttpsError("invalid-argument", "e164Phone is required");
    }

    const email = riderAuthEmail(e164Phone.trim());
    const auth = getAuth();
    let uid: string;

    try {
      const existing = await auth.getUserByEmail(email);
      uid = existing.uid;
      await auth.updateUser(uid, {password: LEGACY_PASSWORD});
    } catch (e: unknown) {
      const code = (e as {code?: string}).code;
      if (code === "auth/user-not-found") {
        const created = await auth.createUser({
          email,
          password: LEGACY_PASSWORD,
          emailVerified: true,
        });
        uid = created.uid;
      } else {
        throw new HttpsError("internal", "Dev rider sign-in failed");
      }
    }

    const customToken = await auth.createCustomToken(uid);
    return {customToken};
  },
);
