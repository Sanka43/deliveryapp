import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {
  onDocumentCreated,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";
import {
  type OrderData,
  type StatMutation,
  mutationsForOrderCreated,
  mutationsForOrderUpdated,
  orderVendorId,
} from "./vendorStatsLogic";

async function applyMutations(
  vendorId: string,
  mutations: StatMutation[],
): Promise<void> {
  const id = vendorId.trim();
  if (!id || mutations.length === 0) {
    return;
  }

  const db = getFirestore();
  const vendorRef = db.collection("vendors").doc(id);
  const batch = db.batch();
  for (const mutation of mutations) {
    const increments = Object.fromEntries(
      Object.entries(mutation.increments).map(([key, value]) => [
        key,
        FieldValue.increment(value),
      ]),
    );
    batch.set(
      vendorRef.collection(mutation.collection).doc(mutation.docId),
      {
        ...mutation.data,
        ...increments,
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
  }
  await batch.commit();
}

export const onOrderCreatedVendorStats = onDocumentCreated(
  {document: "orders/{orderId}", region: "asia-south1"},
  async (event) => {
    const order = event.data?.data() as OrderData | undefined;
    if (!order) {
      return;
    }
    await applyMutations(orderVendorId(order), mutationsForOrderCreated(order));
  },
);

export const onOrderUpdatedVendorStats = onDocumentUpdated(
  {document: "orders/{orderId}", region: "asia-south1"},
  async (event) => {
    const before = event.data?.before.data() as OrderData | undefined;
    const after = event.data?.after.data() as OrderData | undefined;
    if (!before || !after) {
      return;
    }
    const vendorId = orderVendorId(after) || orderVendorId(before);
    await applyMutations(
      vendorId,
      mutationsForOrderUpdated(before, after),
    );
  },
);
