import {FieldValue, getFirestore, Timestamp} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {
  onDocumentCreated,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";

const REGION = "asia-south1";
const DEFAULT_LISTING_MS = 30 * 24 * 60 * 60 * 1000; // 30 days
const DUPLICATE_WINDOW_MS = 24 * 60 * 60 * 1000; // 24 hours
const MAX_LABOR_COUNT = 99;
const MIN_LABOR_COUNT = 1;

function requireString(
  value: unknown,
  field: string,
  options: {min?: number; max?: number} = {},
): string {
  const min = options.min ?? 0;
  const max = options.max ?? 100_000;
  const s = String(value ?? "").trim();
  if (s.length < min || s.length > max) {
    throw new HttpsError("invalid-argument", `Invalid ${field}.`);
  }
  return s;
}

/**
 * Server-authoritative job posting. Previously a client could create a
 * `jobs` document directly (Firestore rules only checked that the poster's
 * `jobPostCredits > 0`, never that this specific write also decremented
 * it) — a modified client could skip the credit-decrement write entirely
 * and post unlimited jobs off a single credit. Creation now goes through
 * this callable so the credit check and decrement are atomic with the job
 * write, and the Firestore `jobs` create rule for non-admins is removed.
 */
export const createJobPost = onCall(
  {region: REGION},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in to post a job.");
    }
    const uid = request.auth.uid;
    const data = (request.data ?? {}) as Record<string, unknown>;

    const title = requireString(data.title, "title", {min: 3, max: 120});
    const category = requireString(data.category, "category", {min: 1, max: 80});
    const type = requireString(data.type, "type", {min: 1, max: 80});
    const salary = String(data.salary ?? "").trim().slice(0, 200);
    const location = String(data.location ?? "").trim().slice(0, 200);
    const description = requireString(data.description, "description", {
      min: 10,
      max: 5000,
    });
    const companyName = requireString(data.companyName, "companyName", {
      min: 1,
      max: 160,
    });
    const contactPhone = requireString(data.contactPhone, "contactPhone", {
      min: 8,
      max: 20,
    });
    if (contactPhone.replace(/\D/g, "").length < 8) {
      throw new HttpsError("invalid-argument", "Invalid contactPhone.");
    }
    const whatsappRaw = String(data.whatsapp ?? "").trim();
    const whatsapp = whatsappRaw.length > 0 ? whatsappRaw.slice(0, 20) : undefined;
    const responsibilities = String(data.responsibilities ?? "").trim().slice(0, 5000);
    const schedule = String(data.schedule ?? "").trim().slice(0, 500);
    const skillsRaw = Array.isArray(data.skills) ? data.skills : [];
    const skills = skillsRaw
      .map((s) => String(s ?? "").trim().slice(0, 60))
      .filter((s) => s.length > 0)
      .slice(0, 20);
    const urgent = data.urgent === true;
    const remote = data.remote === true;
    const city = String(data.city ?? "").trim().slice(0, 80);
    const latitude = data.latitude == null ? null : Number(data.latitude);
    const longitude = data.longitude == null ? null : Number(data.longitude);
    const laborRaw = Number(data.availableLaborCount ?? MIN_LABOR_COUNT);
    const availableLaborCount = Number.isFinite(laborRaw)
      ? Math.min(MAX_LABOR_COUNT, Math.max(MIN_LABOR_COUNT, Math.floor(laborRaw)))
      : MIN_LABOR_COUNT;
    const deadlineMs = data.deadline == null ? null : Number(data.deadline);

    const db = getFirestore();
    const customerRef = db.collection("customers").doc(uid);
    const jobRef = db.collection("jobs").doc();

    // Best-effort duplicate guard (mirrors the client's own pre-check) —
    // spam prevention, not a security boundary. Single-field query (no
    // orderBy) so it doesn't need a new composite index.
    const since = Date.now() - DUPLICATE_WINDOW_MS;
    const recentSnap = await db
      .collection("jobs")
      .where("userId", "==", uid)
      .limit(10)
      .get();
    const normalizedTitle = title.toLowerCase();
    const isDuplicate = recentSnap.docs.some((doc) => {
      const d = doc.data();
      const t = String(d.title ?? "").trim().toLowerCase();
      const created = d.createdAt as Timestamp | undefined;
      return t === normalizedTitle && created != null && created.toMillis() >= since;
    });
    if (isDuplicate) {
      throw new HttpsError(
        "failed-precondition",
        "You already posted a similar job recently. Please wait 24 hours.",
      );
    }

    const now = Timestamp.now();
    const expiresAt = Timestamp.fromMillis(now.toMillis() + DEFAULT_LISTING_MS);

    await db.runTransaction(async (tx) => {
      const customerSnap = await tx.get(customerRef);
      if (!customerSnap.exists) {
        throw new HttpsError(
          "failed-precondition",
          "Complete your profile before posting a job.",
        );
      }
      const customerData = customerSnap.data() ?? {};
      if (customerData.jobsBlocked === true) {
        throw new HttpsError(
          "permission-denied",
          "Job posting is blocked for this account.",
        );
      }
      const credits = Math.floor(Number(customerData.jobPostCredits ?? 0));
      if (!Number.isFinite(credits) || credits <= 0) {
        throw new HttpsError(
          "failed-precondition",
          "Job posting credits required. Contact MND support if you need access.",
        );
      }

      const payload: Record<string, unknown> = {
        title,
        category,
        type,
        salary,
        location,
        description,
        companyName,
        contactPhone,
        responsibilities,
        schedule,
        skills,
        expiresAt,
        userId: uid,
        status: "pending",
        verified: false,
        urgent,
        remote,
        city,
        viewCount: 0,
        reportedCount: 0,
        createdAt: now,
        availableLaborCount,
        serverPlaced: true,
      };
      if (whatsapp) {
        payload.whatsapp = whatsapp;
      }
      if (latitude != null && Number.isFinite(latitude)) {
        payload.latitude = latitude;
      }
      if (longitude != null && Number.isFinite(longitude)) {
        payload.longitude = longitude;
      }
      if (deadlineMs != null && Number.isFinite(deadlineMs)) {
        payload.deadline = Timestamp.fromMillis(deadlineMs);
      }

      tx.set(jobRef, payload);
      tx.update(customerRef, {
        jobPostCredits: credits - 1,
        jobPostCreditsUpdatedAt: FieldValue.serverTimestamp(),
      });
    });

    return {jobId: jobRef.id};
  },
);

/**
 * Auto-expires job listings whose `expiresAt` has passed. Nothing else in
 * the system ever transitions a job out of `active`, so without this an
 * expired listing stays publicly readable/queryable forever. Uses a plain
 * single-field `status` query (no composite index needed) and filters
 * `expiresAt` in code, mirroring `sweepStaleSearchingTrips`'s approach.
 */
export const sweepExpiredJobs = onSchedule(
  {
    schedule: "every 60 minutes",
    timeZone: "Asia/Colombo",
    region: REGION,
    timeoutSeconds: 120,
    memory: "256MiB",
  },
  async () => {
    const db = getFirestore();
    const nowMs = Date.now();
    let scanned = 0;
    let expiredCount = 0;
    let last: FirebaseFirestore.QueryDocumentSnapshot | undefined;

    for (;;) {
      let query = db.collection("jobs").where("status", "==", "active").limit(300);
      if (last) {
        query = query.startAfter(last);
      }
      const snap = await query.get();
      if (snap.empty) {
        break;
      }
      last = snap.docs[snap.docs.length - 1];
      scanned += snap.size;

      const toExpire = snap.docs.filter((doc) => {
        const expiresAt = doc.data().expiresAt as Timestamp | undefined;
        return expiresAt != null && expiresAt.toMillis() <= nowMs;
      });
      if (toExpire.length > 0) {
        const batch = db.batch();
        for (const doc of toExpire) {
          batch.update(doc.ref, {
            status: "expired",
            expiredAt: FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
        expiredCount += toExpire.length;
      }

      if (snap.size < 300) {
        break;
      }
    }

    logger.info("Job expiry sweep complete", {scanned, expiredCount});
  },
);

async function assertAdmin(uid: string): Promise<void> {
  const snap = await getFirestore().collection("customers").doc(uid).get();
  const role = String(snap.data()?.role ?? "").trim().toLowerCase();
  if (role !== "admin") {
    throw new HttpsError("permission-denied", "Admin only.");
  }
}

async function writeJobInboxNotification(input: {
  userId: string;
  jobId: string;
  type: string;
  title: string;
  body: string;
}): Promise<void> {
  await getFirestore().collection("notifications").add({
    userId: input.userId,
    jobId: input.jobId,
    type: input.type,
    title: input.title,
    body: input.body,
    read: false,
    createdAt: FieldValue.serverTimestamp(),
  });
}

async function sendPushToCustomer(input: {
  customerId: string;
  jobId: string;
  title: string;
  body: string;
}): Promise<void> {
  const snap = await getFirestore().collection("customers").doc(input.customerId).get();
  const token = String(snap.data()?.fcmToken ?? "").trim();
  if (!token) {
    logger.warn("No customer FCM token; inbox notification only", {
      customerId: input.customerId,
      jobId: input.jobId,
    });
    return;
  }
  try {
    await getMessaging().send({
      token,
      notification: {title: input.title, body: input.body},
      data: {jobId: input.jobId, screen: "job"},
      android: {priority: "high" as const},
      apns: {payload: {aps: {sound: "default"}}},
    });
  } catch (err) {
    logger.warn("Customer FCM send failed; inbox notification only", {
      err,
      customerId: input.customerId,
      jobId: input.jobId,
    });
  }
}

/**
 * Admin approves a pending job post. Previously a raw client Firestore
 * write from the admin dashboard — now a callable so there's a consistent
 * server-side audit trail (`approvedBy`) alongside the rules-level check.
 */
export const approveJobPost = onCall(
  {region: REGION},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in as admin.");
    }
    await assertAdmin(request.auth.uid);
    const jobId = String(request.data?.jobId ?? "").trim();
    if (!jobId) {
      throw new HttpsError("invalid-argument", "jobId is required.");
    }
    const ref = getFirestore().collection("jobs").doc(jobId);
    await ref.update({
      status: "active",
      approvedAt: FieldValue.serverTimestamp(),
      approvedBy: request.auth.uid,
      rejectionNote: FieldValue.delete(),
      rejectedAt: FieldValue.delete(),
      rejectedBy: FieldValue.delete(),
    });
    return {jobId};
  },
);

/** Admin rejects a pending job post — same audit-trail reasoning as approveJobPost. */
export const rejectJobPost = onCall(
  {region: REGION},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in as admin.");
    }
    await assertAdmin(request.auth.uid);
    const jobId = String(request.data?.jobId ?? "").trim();
    if (!jobId) {
      throw new HttpsError("invalid-argument", "jobId is required.");
    }
    const note = String(request.data?.note ?? "").trim().slice(0, 500);
    const ref = getFirestore().collection("jobs").doc(jobId);
    await ref.update({
      status: "rejected",
      rejectedAt: FieldValue.serverTimestamp(),
      rejectedBy: request.auth.uid,
      ...(note ? {rejectionNote: note} : {}),
    });
    return {jobId};
  },
);

/** Notifies a job's poster when their pending listing is approved or rejected. */
export const onJobStatusUpdatedNotify = onDocumentUpdated(
  {document: "jobs/{jobId}", region: REGION},
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) {
      return;
    }
    const beforeStatus = String(before.status ?? "").trim().toLowerCase();
    const afterStatus = String(after.status ?? "").trim().toLowerCase();
    if (beforeStatus !== "pending" || beforeStatus === afterStatus) {
      return;
    }
    const jobId = event.params.jobId;
    const userId = String(after.userId ?? "").trim();
    if (!userId) {
      return;
    }
    const title = String(after.title ?? "Your job post").trim();

    if (afterStatus === "active") {
      const body = `"${title}" is now live and visible to job seekers.`;
      await writeJobInboxNotification({
        userId,
        jobId,
        type: "job_approved",
        title: "Job post approved",
        body,
      });
      await sendPushToCustomer({customerId: userId, jobId, title: "Job post approved", body});
    } else if (afterStatus === "rejected") {
      const noteText = String(after.rejectionNote ?? "").trim();
      const body = noteText
        ? `"${title}" was not approved: ${noteText}`
        : `"${title}" was not approved. Check the app for details.`;
      await writeJobInboxNotification({
        userId,
        jobId,
        type: "job_rejected",
        title: "Job post rejected",
        body,
      });
      await sendPushToCustomer({customerId: userId, jobId, title: "Job post rejected", body});
    }
  },
);

/** Notifies a job's poster when someone applies. */
export const onJobApplicationCreatedNotify = onDocumentCreated(
  {document: "job_applications/{applicationId}", region: REGION},
  async (event) => {
    const data = event.data?.data();
    if (!data) {
      return;
    }
    const jobId = String(data.jobId ?? "").trim();
    const applicantName = String(data.applicantName ?? "Someone").trim() || "Someone";
    if (!jobId) {
      return;
    }
    const jobSnap = await getFirestore().collection("jobs").doc(jobId).get();
    const jobData = jobSnap.data();
    if (!jobData) {
      return;
    }
    const posterId = String(jobData.userId ?? "").trim();
    if (!posterId) {
      return;
    }
    const jobTitle = String(jobData.title ?? "your job post").trim();
    const title = "New applicant";
    const body = `${applicantName} applied for "${jobTitle}".`;
    await writeJobInboxNotification({
      userId: posterId,
      jobId,
      type: "job_application",
      title,
      body,
    });
    await sendPushToCustomer({customerId: posterId, jobId, title, body});
  },
);
