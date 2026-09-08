import {getAuth} from "firebase-admin/auth";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";
import {logger} from "firebase-functions";
import {HttpsError, onCall} from "firebase-functions/v2/https";

const REGION = "asia-south1";
const SUPPORT_EMAIL = "masterndelivery111@gmail.com";
const TERMINAL_STATUSES = new Set(["auth_deleted", "completed"]);

function normalizeReason(raw: unknown): string {
  if (typeof raw !== "string") {
    return "";
  }
  return raw.trim().slice(0, 500);
}

function readDeletionStatus(data: Record<string, unknown>): string {
  return typeof data.accountDeletionStatus === "string" ?
    data.accountDeletionStatus.trim().toLowerCase() :
    "";
}

function toWholeLkr(value: unknown): number {
  const n = Math.round(Number(value));
  return Number.isFinite(n) ? n : 0;
}

async function queueAdminDeletionMail(params: {
  riderId: string;
  riderName: string;
  phone: string;
  reason: string;
}): Promise<void> {
  const db = getFirestore();
  const reasonBlock = params.reason.length > 0 ?
    `\nReason: ${params.reason}` :
    "";
  await db.collection("mail").add({
    to: [SUPPORT_EMAIL],
    message: {
      subject: `MND Rider — account deletion (${params.riderName})`,
      text:
        `A rider completed self-service account deletion.\n\n` +
        `Rider: ${params.riderName}\n` +
        `Rider id: ${params.riderId}\n` +
        `Phone: ${params.phone || "(none)"}` +
        reasonBlock +
        "\n\nFirebase Auth was removed and compliance photos were deleted " +
        "from Storage. Earnings, cash-ledger, and payout records were kept " +
        "for audit purposes.",
      html:
        `<p>A rider completed self-service account deletion.</p>` +
        `<p><strong>Rider:</strong> ${params.riderName}<br/>` +
        `<strong>Rider id:</strong> ${params.riderId}<br/>` +
        `<strong>Phone:</strong> ${params.phone || "(none)"}</p>` +
        (params.reason.length > 0 ?
          `<p><strong>Reason:</strong> ${params.reason}</p>` :
          "") +
        `<p>Firebase Auth was removed and compliance photos were deleted ` +
        `from Storage. Earnings, cash-ledger, and payout records were kept ` +
        `for audit purposes.</p>`,
    },
    createdAt: FieldValue.serverTimestamp(),
    type: "rider_account_deletion_request",
    riderId: params.riderId,
  });
}

async function deleteRiderStorageFiles(riderId: string): Promise<void> {
  try {
    await getStorage().bucket().deleteFiles({prefix: `riders/${riderId}/`});
  } catch (error) {
    logger.error("rider storage cleanup failed", {riderId, error});
  }
}

/**
 * Rider-initiated account closure: removes Firebase Auth sign-in and
 * compliance/profile photos, but retains earnings, cash-ledger, and payout
 * subcollections under `riders/{riderId}` for financial audit — mirrors
 * `requestVendorAccountDeletion`. Cash still owed to admin blocks deletion
 * so a rider cannot disappear while holding platform cash.
 */
export const requestRiderAccountDeletion = onCall(
  {region: REGION, invoker: "public"},
  async (request) => {
    const uid = request.auth?.uid?.trim();
    if (!uid) {
      throw new HttpsError(
        "unauthenticated",
        "Sign in again to request account deletion.",
      );
    }

    const reason = normalizeReason(request.data?.reason);
    const db = getFirestore();
    const riderRef = db.collection("riders").doc(uid);
    const snap = await riderRef.get();
    if (!snap.exists) {
      throw new HttpsError(
        "not-found",
        "Rider account not found. Contact support.",
      );
    }

    const data = snap.data() ?? {};
    const ownerUid = typeof data.uid === "string" ? data.uid.trim() : "";
    if (ownerUid !== uid) {
      throw new HttpsError(
        "permission-denied",
        "This rider account cannot be deleted from this login.",
      );
    }

    const existingStatus = readDeletionStatus(data);
    if (TERMINAL_STATUSES.has(existingStatus)) {
      return {ok: true, status: existingStatus};
    }

    const cashOwed = toWholeLkr(data.cashOwedToAdminLkr);
    const cashPending = toWholeLkr(data.cashPendingSettlementLkr);
    if (cashOwed > 0 || cashPending > 0) {
      throw new HttpsError(
        "failed-precondition",
        "Hand over your collected cash before deleting your account.",
      );
    }

    const riderName =
      typeof data.fullName === "string" && data.fullName.trim().length > 0 ?
        data.fullName.trim() :
        "MND Rider";
    const phone = typeof data.phone === "string" ? data.phone.trim() : "";

    if (existingStatus !== "pending") {
      await riderRef.set(
        {
          online: false,
          accountDeletionStatus: "pending",
          accountDeletionRequestedAt: FieldValue.serverTimestamp(),
          accountDeletionReason: reason.length > 0 ? reason : null,
          updatedAt: FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
    }

    await queueAdminDeletionMail({riderId: uid, riderName, phone, reason});
    await deleteRiderStorageFiles(uid);

    try {
      await db.collection("rider_locations").doc(uid).delete();
    } catch (error) {
      logger.error("rider location cleanup failed", {uid, error});
    }

    try {
      await getAuth().deleteUser(uid);
    } catch (error) {
      logger.error("rider auth deletion failed", {uid, error});
      throw new HttpsError(
        "internal",
        "Could not complete account deletion. Try again or contact support.",
      );
    }

    await riderRef.set(
      {
        online: false,
        accountDeletionStatus: "auth_deleted",
        accountDeletionCompletedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

    return {ok: true, status: "auth_deleted"};
  },
);
