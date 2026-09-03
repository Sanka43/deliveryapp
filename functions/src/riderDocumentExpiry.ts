import {FieldValue, Timestamp, getFirestore} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {onSchedule} from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";

/**
 * Daily sweep for rider compliance-document expiry (driving license,
 * insurance, revenue license). For each approved/active rider:
 *  - sends a reminder push+inbox notification at 14/7/1 days before expiry
 *    (bucketed + marker-tracked so a delayed/missed run still self-heals
 *    instead of silently skipping a rider's only reminder for a window), and
 *  - once actually expired, flips `status` to 'pending' and `online` to
 *    false server-side, so an already-online rider can't keep taking jobs
 *    on an expired document — nothing else in the app enforces this.
 */
const REGION = "asia-south1";
const REMINDER_BUCKETS = [1, 7, 14] as const;
const COLOMBO_OFFSET_MS = 5.5 * 60 * 60 * 1000;

type DocKind = "license" | "insurance" | "revenueLicense";

interface DocKindConfig {
  key: DocKind;
  label: string;
  expiresAtField: string;
  markerField: string;
}

const DOC_KINDS: DocKindConfig[] = [
  {
    key: "license",
    label: "Driving license",
    expiresAtField: "licenseExpiresAt",
    markerField: "licenseReminderDaysSent",
  },
  {
    key: "insurance",
    label: "Insurance",
    expiresAtField: "insuranceExpiresAt",
    markerField: "insuranceReminderDaysSent",
  },
  {
    key: "revenueLicense",
    label: "Revenue license",
    expiresAtField: "revenueLicenseExpiresAt",
    markerField: "revenueLicenseReminderDaysSent",
  },
];

/** Calendar-day bucket (UTC ms) in Asia/Colombo, matching how the client
 * writes date-only expiry timestamps (`Timestamp.fromDate(DateTime(y,m,d))`
 * in the device's local time, which for this app's users is Colombo). */
function colomboDateOnlyMs(date: Date): number {
  const shifted = new Date(date.getTime() + COLOMBO_OFFSET_MS);
  return Date.UTC(shifted.getUTCFullYear(), shifted.getUTCMonth(), shifted.getUTCDate());
}

export function daysUntilExpiry(expiresAt: unknown, nowMs: number): number | null {
  if (!(expiresAt instanceof Timestamp)) {
    return null;
  }
  const expiryDay = colomboDateOnlyMs(expiresAt.toDate());
  const todayDay = colomboDateOnlyMs(new Date(nowMs));
  return Math.round((expiryDay - todayDay) / (24 * 60 * 60 * 1000));
}

/** Smallest reminder bucket that covers `daysLeft`, or null outside 0-14. */
export function reminderBucketFor(daysLeft: number): number | null {
  if (daysLeft < 0) {
    return null;
  }
  for (const bucket of REMINDER_BUCKETS) {
    if (daysLeft <= bucket) {
      return bucket;
    }
  }
  return null;
}

async function writeRiderInboxNotification(input: {
  riderId: string;
  notificationId: string;
  type: string;
  title: string;
  body: string;
}): Promise<void> {
  await getFirestore()
    .collection("riders")
    .doc(input.riderId)
    .collection("notifications")
    .doc(input.notificationId)
    .set(
      {
        type: input.type,
        title: input.title,
        body: input.body,
        read: false,
        createdAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
}

async function sendPushToRider(input: {
  riderId: string;
  title: string;
  body: string;
  type: string;
}): Promise<void> {
  const riderSnap = await getFirestore().collection("riders").doc(input.riderId).get();
  const token = String(riderSnap.data()?.fcmToken ?? "").trim();
  if (!token) {
    return;
  }
  try {
    await getMessaging().send({
      token,
      notification: {title: input.title, body: input.body},
      data: {type: input.type, title: input.title, body: input.body},
      android: {priority: "high" as const},
      apns: {payload: {aps: {sound: "default"}}},
    });
  } catch (err) {
    logger.warn("Rider FCM send failed", {err, riderId: input.riderId});
  }
}

async function notifyDocumentExpiring(
  riderId: string,
  kind: DocKindConfig,
  bucket: number,
): Promise<void> {
  const title = "Document expiring soon";
  const body = `Your ${kind.label.toLowerCase()} expires in ${bucket} day${bucket === 1 ? "" : "s"}. Renew it in the app to keep taking jobs.`;
  await writeRiderInboxNotification({
    riderId,
    notificationId: `${riderId}_${kind.key}_reminder_${bucket}`,
    type: "documents_expiring",
    title,
    body,
  });
  await sendPushToRider({riderId, title, body, type: "documents_expiring"});
}

async function notifyDocumentsExpired(riderId: string, expiredLabels: string[]): Promise<void> {
  const title = "Document expired";
  const body = `${expiredLabels.join(", ")} expired. Renew it now — you can't go online until it's updated.`;
  await writeRiderInboxNotification({
    riderId,
    notificationId: `${riderId}_documents_expired`,
    type: "documents_expired",
    title,
    body,
  });
  await sendPushToRider({riderId, title, body, type: "documents_expired"});
}

export const sweepRiderDocumentExpiry = onSchedule(
  {
    schedule: "0 8 * * *",
    timeZone: "Asia/Colombo",
    region: REGION,
    timeoutSeconds: 120,
    memory: "256MiB",
  },
  async () => {
    const db = getFirestore();
    const nowMs = Date.now();
    const snap = await db
      .collection("riders")
      .where("status", "in", ["approved", "active"])
      .get();

    const writes: Array<{
      ref: FirebaseFirestore.DocumentReference;
      data: Record<string, unknown>;
    }> = [];
    const notifications: Array<() => Promise<void>> = [];
    let reminderCount = 0;
    let expiredRiderCount = 0;

    for (const doc of snap.docs) {
      const data = doc.data();
      const riderId = doc.id;
      const patch: Record<string, unknown> = {};
      const expiredKinds: DocKindConfig[] = [];

      for (const kind of DOC_KINDS) {
        const daysLeft = daysUntilExpiry(data[kind.expiresAtField], nowMs);
        if (daysLeft === null) {
          continue;
        }

        if (daysLeft < 0) {
          expiredKinds.push(kind);
          continue;
        }

        const bucket = reminderBucketFor(daysLeft);
        if (bucket !== null && data[kind.markerField] !== bucket) {
          patch[kind.markerField] = bucket;
          reminderCount += 1;
          notifications.push(() => notifyDocumentExpiring(riderId, kind, bucket));
        }
      }

      if (expiredKinds.length > 0) {
        patch.status = "pending";
        patch.online = false;
        patch.complianceExpiredFields = expiredKinds.map((k) => k.key);
        patch.updatedAt = FieldValue.serverTimestamp();
        expiredRiderCount += 1;
        notifications.push(() =>
          notifyDocumentsExpired(riderId, expiredKinds.map((k) => k.label)),
        );
      }

      if (Object.keys(patch).length > 0) {
        writes.push({ref: doc.ref, data: patch});
      }
    }

    // Firestore batches cap at 500 writes; chunk defensively.
    for (let i = 0; i < writes.length; i += 400) {
      const batch = db.batch();
      for (const w of writes.slice(i, i + 400)) {
        batch.set(w.ref, w.data, {merge: true});
      }
      await batch.commit();
    }

    await Promise.all(notifications.map((send) => send()));

    logger.info(
      `Document expiry sweep: ${snap.size} riders checked, ` +
        `${reminderCount} reminders sent, ${expiredRiderCount} riders flagged expired`,
    );
  },
);
