import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {onDocumentUpdated} from "firebase-functions/v2/firestore";
import {loadPlatformFeeConfig} from "./platformConfig";
import {
  type CashFlowMutation,
  mutationsForMonthlyInvoiceUpdated,
  mutationsForOrderUpdated,
  mutationsForPayoutUpdated,
  mutationsForTripUpdated,
  mutationsForWithdrawalUpdated,
} from "./platformCashFlowLogic";

const REGION = "asia-south1";

/**
 * Platform-wide daily cash-flow aggregate (`platform_daily_cashflow/{dateKey}`)
 * for the mnd_web admin "Cash Flow" tab — deliberately separate, additive
 * triggers that only ever READ the settlement/order documents these events
 * fire on, never write back to them. A bug here can produce a wrong number
 * on the Cash Flow tab; it cannot break an actual withdrawal, payout, or
 * order (see platformCashFlowLogic.ts for what each event tracks and why
 * orderRiderCommissionLkr is deliberately left out of Phase 1).
 */
async function applyMutations(mutations: CashFlowMutation[]): Promise<void> {
  if (mutations.length === 0) {
    return;
  }
  const db = getFirestore();
  const ref = db.collection("platform_daily_cashflow");
  const batch = db.batch();
  for (const mutation of mutations) {
    const increments = Object.fromEntries(
      Object.entries(mutation.increments).map(([key, value]) => [
        key,
        FieldValue.increment(value),
      ]),
    );
    batch.set(
      ref.doc(mutation.docId),
      {date: mutation.docId, ...increments, updatedAt: FieldValue.serverTimestamp()},
      {merge: true},
    );
  }
  await batch.commit();
}

export const onOrderUpdatedCashFlow = onDocumentUpdated(
  {document: "orders/{orderId}", region: REGION},
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) {
      return;
    }
    await applyMutations(mutationsForOrderUpdated(before, after, new Date()));
  },
);

export const onTripUpdatedCashFlow = onDocumentUpdated(
  {document: "trips/{tripId}", region: REGION},
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) {
      return;
    }
    const {rideCommissionLkr} = await loadPlatformFeeConfig();
    await applyMutations(
      mutationsForTripUpdated(before, after, rideCommissionLkr, new Date()),
    );
  },
);

export const onWithdrawalUpdatedCashFlow = onDocumentUpdated(
  {document: "riders/{riderId}/withdrawals/{withdrawalId}", region: REGION},
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) {
      return;
    }
    await applyMutations(mutationsForWithdrawalUpdated(before, after, new Date()));
  },
);

export const onVendorPayoutUpdatedCashFlow = onDocumentUpdated(
  {document: "vendors/{vendorId}/payouts/{payoutId}", region: REGION},
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) {
      return;
    }
    await applyMutations(mutationsForPayoutUpdated(before, after, new Date()));
  },
);

export const onMonthlyInvoiceUpdatedCashFlow = onDocumentUpdated(
  {document: "vendors/{vendorId}/monthly_invoices/{monthKey}", region: REGION},
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) {
      return;
    }
    await applyMutations(
      mutationsForMonthlyInvoiceUpdated(before, after, new Date()),
    );
  },
);
