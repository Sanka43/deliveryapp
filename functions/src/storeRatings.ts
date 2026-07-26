import {getFirestore} from "firebase-admin/firestore";
import {
  onDocumentCreated,
  onDocumentDeleted,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";

type StoreRatingData = {
  vendorId?: unknown;
  status?: unknown;
  stars?: unknown;
};

function vendorIdOf(data: StoreRatingData | undefined): string {
  if (!data || typeof data.vendorId !== "string") {
    return "";
  }
  return data.vendorId.trim();
}

function roundOneDecimal(value: number): number {
  return Math.round(value * 10) / 10;
}

async function recomputeVendorRating(vendorId: string): Promise<void> {
  const id = vendorId.trim();
  if (!id) {
    return;
  }

  const db = getFirestore();
  const snap = await db
    .collection("store_ratings")
    .where("vendorId", "==", id)
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
  await db.collection("vendors").doc(id).set(
    {
      rating,
      ratingCount: count,
    },
    {merge: true},
  );
}

export const onStoreRatingCreated = onDocumentCreated(
  {document: "store_ratings/{orderId}", region: "asia-south1"},
  async (event) => {
    const data = event.data?.data() as StoreRatingData | undefined;
    await recomputeVendorRating(vendorIdOf(data));
  },
);

export const onStoreRatingUpdated = onDocumentUpdated(
  {document: "store_ratings/{orderId}", region: "asia-south1"},
  async (event) => {
    const before = event.data?.before.data() as StoreRatingData | undefined;
    const after = event.data?.after.data() as StoreRatingData | undefined;
    const beforeVendor = vendorIdOf(before);
    const afterVendor = vendorIdOf(after);
    if (beforeVendor && beforeVendor !== afterVendor) {
      await recomputeVendorRating(beforeVendor);
    }
    await recomputeVendorRating(afterVendor || beforeVendor);
  },
);

export const onStoreRatingDeleted = onDocumentDeleted(
  {document: "store_ratings/{orderId}", region: "asia-south1"},
  async (event) => {
    const data = event.data?.data() as StoreRatingData | undefined;
    await recomputeVendorRating(vendorIdOf(data));
  },
);
