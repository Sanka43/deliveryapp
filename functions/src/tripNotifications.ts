import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {onDocumentUpdated} from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";

const REGION = "asia-south1";

const TRIP_STATUS_COPY: Record<string, {title: string; body: string}> = {
  accepted: {
    title: "Driver assigned",
    body: "Your rider is on the way to pickup.",
  },
  arrived: {
    title: "Driver arrived",
    body: "Your rider has arrived at the pickup point.",
  },
  in_progress: {
    title: "Trip started",
    body: "You are on the way to your destination.",
  },
  completed: {
    title: "Trip completed",
    body: "Thanks for riding with MND.",
  },
  cancelled: {
    title: "Trip cancelled",
    body: "Your ride was cancelled.",
  },
};

async function writeCustomerInbox(input: {
  userId: string;
  tripId: string;
  type: string;
  title: string;
  body: string;
  status?: string;
}): Promise<void> {
  if (!input.userId) {
    return;
  }
  await getFirestore().collection("notifications").add({
    userId: input.userId,
    tripId: input.tripId,
    type: input.type,
    title: input.title,
    body: input.body,
    status: input.status ?? null,
    read: false,
    createdAt: FieldValue.serverTimestamp(),
  });
}

async function writeRiderInbox(input: {
  riderId: string;
  notificationId: string;
  type: string;
  title: string;
  body: string;
  tripId?: string;
  orderId?: string;
  amountLkr?: number;
}): Promise<void> {
  const riderId = input.riderId.trim();
  if (!riderId) {
    return;
  }
  await getFirestore()
    .collection("riders")
    .doc(riderId)
    .collection("notifications")
    .doc(input.notificationId)
    .set(
      {
        type: input.type,
        title: input.title,
        body: input.body,
        tripId: input.tripId ?? null,
        orderId: input.orderId ?? null,
        amountLkr: input.amountLkr ?? null,
        read: false,
        createdAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
}

async function sendPushToCustomer(input: {
  customerId: string;
  tripId: string;
  title: string;
  body: string;
  status?: string;
}): Promise<void> {
  const customerSnap = await getFirestore()
    .collection("customers")
    .doc(input.customerId)
    .get();
  const token = String(customerSnap.data()?.fcmToken ?? "").trim();
  if (!token) {
    logger.warn("No customer FCM token for trip update", {
      customerId: input.customerId,
      tripId: input.tripId,
    });
    return;
  }

  try {
    await getMessaging().send({
      token,
      notification: {title: input.title, body: input.body},
      data: {
        tripId: input.tripId,
        screen: "ride_tracking",
        status: input.status ?? "",
        title: input.title,
        body: input.body,
      },
      android: {priority: "high"},
      apns: {payload: {aps: {sound: "default"}}},
    });
  } catch (err) {
    logger.warn("Customer trip FCM failed", {err, tripId: input.tripId});
  }
}

async function sendPushToRider(input: {
  riderId: string;
  title: string;
  body: string;
  type: string;
  tripId?: string;
  orderId?: string;
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
      data: {
        type: input.type,
        tripId: input.tripId ?? "",
        orderId: input.orderId ?? "",
        title: input.title,
        body: input.body,
      },
      android: {priority: "high"},
      apns: {payload: {aps: {sound: "default"}}},
    });
  } catch (err) {
    logger.warn("Rider FCM failed", {err, riderId: input.riderId});
  }
}

/**
 * Customer + rider alerts when passenger trip status changes.
 */
export const onTripStatusUpdatedNotify = onDocumentUpdated(
  {document: "trips/{tripId}", region: REGION},
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) {
      return;
    }

    const prevStatus = String(before.status ?? "").trim().toLowerCase();
    const nextStatus = String(after.status ?? "").trim().toLowerCase();
    if (!nextStatus || prevStatus === nextStatus) {
      return;
    }

    const tripId = event.params.tripId;
    const customerId = String(after.customerId ?? "").trim();
    const riderId = String(after.riderId ?? after.assignedRiderId ?? "").trim();
    const copy = TRIP_STATUS_COPY[nextStatus] ?? {
      title: "Ride update",
      body: `Status: ${nextStatus}`,
    };

    const tasks: Array<Promise<unknown>> = [];

    if (customerId) {
      tasks.push(
        writeCustomerInbox({
          userId: customerId,
          tripId,
          type: "ride_status",
          title: copy.title,
          body: copy.body,
          status: nextStatus,
        }),
      );
      tasks.push(
        sendPushToCustomer({
          customerId,
          tripId,
          title: copy.title,
          body: copy.body,
          status: nextStatus,
        }),
      );
    }

    if (riderId && (nextStatus === "cancelled" || nextStatus === "completed")) {
      const riderTitle =
        nextStatus === "cancelled" ? "Ride cancelled" : "Ride completed";
      const riderBody =
        nextStatus === "cancelled"
          ? "A passenger ride was cancelled."
          : "Trip finished — earnings will appear in your wallet.";
      tasks.push(
        writeRiderInbox({
          riderId,
          notificationId: `${tripId}_${nextStatus}`,
          type: "ride_update",
          title: riderTitle,
          body: riderBody,
          tripId,
        }),
      );
      tasks.push(
        sendPushToRider({
          riderId,
          title: riderTitle,
          body: riderBody,
          type: "ride_update",
          tripId,
        }),
      );
    }

    await Promise.all(tasks);
  },
);
