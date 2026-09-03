import {HttpsError, beforeUserCreated} from "firebase-functions/v2/identity";

/**
 * Blocks bare email/password signup for synthetic rider emails
 * (`rider.{digits}@riders.mnd.app`). Real riders verify phone OTP first, then
 * link email/password onto that same Auth user (no new-user create).
 *
 * Requires Firebase Auth Blocking Functions / Identity Platform enabled.
 * Region must stay on the Auth blocking default (us-east1) so Identity
 * Platform can invoke this trigger; requires firebase-functions >= 7.2.2
 * for correct run.app / cloudfunctions.net audience verification.
 */
export const blockSyntheticRiderEmailSignup = beforeUserCreated(
  {
    region: "us-east1",
    // Auth blocking must finish within ~7s. Cold starts in us-east1 routinely
    // exceed that and fail customer/rider phone OTP with
    // "Cloud function deadline exceeded" (auth/internal-error).
    minInstances: 1,
    memory: "256MiB",
    concurrency: 80,
  },
  (event) => {
    const email = (event.data?.email ?? "").trim().toLowerCase();
    // Fast path for phone OTP / non-rider signups (no I/O).
    if (!email.endsWith("@riders.mnd.app")) {
      return;
    }
    throw new HttpsError(
      "permission-denied",
      "Rider accounts must verify phone OTP before setting a password.",
    );
  },
);
