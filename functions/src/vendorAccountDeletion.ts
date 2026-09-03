import {getAuth} from "firebase-admin/auth";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
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

async function queueAdminDeletionMail(params: {
  vendorId: string;
  shopName: string;
  email: string;
  reason: string;
}): Promise<void> {
  const db = getFirestore();
  const reasonBlock = params.reason.length > 0 ?
    `\nReason: ${params.reason}` :
    "";
  await db.collection("mail").add({
    to: [SUPPORT_EMAIL],
    message: {
      subject: `MND Shop — account deletion (${params.shopName})`,
      text:
        `A vendor completed self-service account deletion.\n\n` +
        `Shop: ${params.shopName}\n` +
        `Vendor id: ${params.vendorId}\n` +
        `Email: ${params.email || "(none)"}` +
        reasonBlock +
        "\n\nFirebase Auth was removed. Shop profile data may be retained per policy.",
      html:
        `<p>A vendor completed self-service account deletion.</p>` +
        `<p><strong>Shop:</strong> ${params.shopName}<br/>` +
        `<strong>Vendor id:</strong> ${params.vendorId}<br/>` +
        `<strong>Email:</strong> ${params.email || "(none)"}</p>` +
        (params.reason.length > 0 ?
          `<p><strong>Reason:</strong> ${params.reason}</p>` :
          "") +
        `<p>Firebase Auth was removed. Shop profile data may be retained per policy.</p>`,
    },
    createdAt: FieldValue.serverTimestamp(),
    type: "vendor_account_deletion_request",
    vendorId: params.vendorId,
  });
}

/**
 * Vendor-initiated account closure: close shop, delete Firebase Auth, retain
 * Firestore records where legally required.
 */
export const requestVendorAccountDeletion = onCall(
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
    const vendorRef = db.collection("vendors").doc(uid);
    const snap = await vendorRef.get();
    if (!snap.exists) {
      throw new HttpsError(
        "not-found",
        "Vendor account not found. Contact support.",
      );
    }

    const data = snap.data() ?? {};
    const ownerUid = typeof data.uid === "string" ? data.uid.trim() : "";
    if (ownerUid !== uid) {
      throw new HttpsError(
        "permission-denied",
        "This shop account cannot be deleted from this login.",
      );
    }

    const existingStatus = readDeletionStatus(data);
    if (TERMINAL_STATUSES.has(existingStatus)) {
      return {ok: true, status: existingStatus};
    }

    const shopName =
      typeof data.name === "string" && data.name.trim().length > 0 ?
        data.name.trim() :
        "MND Shop";
    const email =
      typeof data.email === "string" ? data.email.trim() : "";

    if (existingStatus !== "pending") {
      await vendorRef.set(
        {
          active: false,
          accountDeletionStatus: "pending",
          accountDeletionRequestedAt: FieldValue.serverTimestamp(),
          accountDeletionReason: reason.length > 0 ? reason : null,
          updatedAt: FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
    }

    await queueAdminDeletionMail({
      vendorId: uid,
      shopName,
      email,
      reason,
    });

    try {
      await getAuth().deleteUser(uid);
    } catch (error) {
      logger.error("vendor auth deletion failed", {uid, error});
      throw new HttpsError(
        "internal",
        "Could not complete account deletion. Try again or contact support.",
      );
    }

    await vendorRef.set(
      {
        active: false,
        accountDeletionStatus: "auth_deleted",
        accountDeletionCompletedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

    return {ok: true, status: "auth_deleted"};
  },
);
