import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";

const MAX_PREVIEW_LENGTH = 300;

async function sendSupportReplyPush(input: {
  customerId: string;
  body: string;
}): Promise<void> {
  const customerSnap = await getFirestore()
    .collection("customers")
    .doc(input.customerId)
    .get();
  const token = String(customerSnap.data()?.fcmToken ?? "").trim();
  if (!token) {
    logger.warn("No customer FCM token for support reply push", {
      customerId: input.customerId,
    });
    return;
  }
  const title = "Support replied";
  try {
    await getMessaging().send({
      token,
      notification: {title, body: input.body},
      data: {screen: "support", title, body: input.body},
      android: {priority: "high" as const},
      apns: {payload: {aps: {sound: "default"}}},
    });
  } catch (err) {
    logger.warn("Support reply FCM send failed", {err, customerId: input.customerId});
  }
}

/**
 * Keeps `support_threads/{customerId}` aggregate fields (last message,
 * unread counters, customer snapshot) in sync whenever a message is added
 * to its `messages` subcollection — from the customer app, or added
 * directly in the Firebase console by support staff (there is no admin
 * console for this yet). Also pushes a notification to the customer when
 * staff reply.
 */
export const onSupportMessageCreated = onDocumentCreated(
  {
    document: "support_threads/{customerId}/messages/{messageId}",
    region: "asia-south1",
  },
  async (event) => {
    const data = event.data?.data();
    if (!data) {
      return;
    }
    const customerId = event.params.customerId;
    const senderType =
      String(data.senderType ?? "").trim() === "staff" ? "staff" : "customer";
    const text = String(data.text ?? "").trim();
    const preview =
      text.length > MAX_PREVIEW_LENGTH ?
        `${text.slice(0, MAX_PREVIEW_LENGTH)}…` :
        text;

    const threadRef = getFirestore().collection("support_threads").doc(customerId);
    const threadSnap = await threadRef.get();

    const update: Record<string, unknown> = {
      lastMessageText: preview,
      lastMessageAt: FieldValue.serverTimestamp(),
      lastSenderType: senderType,
      updatedAt: FieldValue.serverTimestamp(),
    };
    if (senderType === "customer") {
      update.status = "open";
      update.unreadByStaff = FieldValue.increment(1);
    } else {
      update.unreadByCustomer = FieldValue.increment(1);
    }

    if (!threadSnap.exists) {
      const customerSnap = await getFirestore()
        .collection("customers")
        .doc(customerId)
        .get();
      const customerData = customerSnap.data() ?? {};
      update.customerId = customerId;
      update.customerName =
        String(customerData.displayName ?? "").trim() || "Customer";
      update.customerPhone = String(customerData.phoneNumber ?? "").trim();
      update.status = update.status ?? "open";
      update.unreadByStaff = update.unreadByStaff ?? 0;
      update.unreadByCustomer = update.unreadByCustomer ?? 0;
      update.createdAt = FieldValue.serverTimestamp();
    }

    await threadRef.set(update, {merge: true});

    if (senderType === "staff" && preview) {
      await sendSupportReplyPush({customerId, body: preview});
    }
  },
);
