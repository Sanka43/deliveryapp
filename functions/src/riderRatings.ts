import {getFirestore} from "firebase-admin/firestore";
import {
  onDocumentCreated,
  onDocumentDeleted,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";

type RiderRatingData = {
  riderId?: unknown;
  status?: unknown;
  stars?: unknown;
};

function riderIdOf(data: RiderRatingData | undefined): string {
  if (!data || typeof data.riderId !== "string") {
    return "";
  }
  return data.riderId.trim();
}

function roundOneDecimal(value: number): number {
  return Math.round(value * 10) / 10;
}

async function recomputeRiderRating(riderId: string): Promise<void> {
  const id = riderId.trim();
  if (!id) {
    return;
  }

  const db = getFirestore();
  const snap = await db
    .collection("rider_ratings")
    .where("riderId", "==", id)
    .where("status", "==", "visible")
    .get();

  let sum = 0;
  let count = 0;
  for (const doc of snap.docs) {
    const stars = doc.data().stars;
    if (typeof stars === "number" && Number.isFinite(stars) && stars >= 1 && stars <= 5) {
      sum += stars;
      count += 1;
    }
  }

  const rating = count === 0 ? 0 : roundOneDecimal(sum / count);
  await db.collection("riders").doc(id).set(
    {
      rating,
      ratingCount: count,
    },
    {merge: true},
  );
}

export const onRiderRatingCreated = onDocumentCreated(
  {document: "rider_ratings/{orderId}", region: "asia-south1"},
  async (event) => {
    const data = event.data?.data() as RiderRatingData | undefined;
    await recomputeRiderRating(riderIdOf(data));
  },
);

export const onRiderRatingUpdated = onDocumentUpdated(
  {document: "rider_ratings/{orderId}", region: "asia-south1"},
  async (event) => {
    const before = event.data?.before.data() as RiderRatingData | undefined;
    const after = event.data?.after.data() as RiderRatingData | undefined;
    const beforeRider = riderIdOf(before);
    const afterRider = riderIdOf(after);
    if (beforeRider && beforeRider !== afterRider) {
      await recomputeRiderRating(beforeRider);
    }
    await recomputeRiderRating(afterRider || beforeRider);
  },
);

export const onRiderRatingDeleted = onDocumentDeleted(
  {document: "rider_ratings/{orderId}", region: "asia-south1"},
  async (event) => {
    const data = event.data?.data() as RiderRatingData | undefined;
    await recomputeRiderRating(riderIdOf(data));
  },
);
