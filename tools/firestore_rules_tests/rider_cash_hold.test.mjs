// Regression test for the rider cash-in-hand hold (riderCashHoldActive() in
// mnd_customer/firestore.rules, maintained by functions/src/riderCash.ts).
//
// A rider holding more collected cash than platform_config/fees allows must
// stop being able to CLAIM new work — both passenger trips and shop delivery
// orders — until an admin confirms they handed the money over. Work already
// in flight must stay finishable, otherwise a rider who crosses the limit
// mid-ride would strand a passenger.
//
// Run from repo root:
//   firebase emulators:exec --only firestore "node tools/firestore_rules_tests/rider_cash_hold.test.mjs"
import { readFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import { doc, setDoc, updateDoc, serverTimestamp } from 'firebase/firestore';

const here = dirname(fileURLToPath(import.meta.url));
const rulesPath = resolve(here, '../../mnd_customer/firestore.rules');

const CLEAR_RIDER = 'riderClear';
const HELD_RIDER = 'riderHeld';
const CUSTOMER = 'cust1';

let passed = 0;
let failed = 0;
const failures = [];

async function check(name, promise) {
  try {
    await promise;
    passed += 1;
    console.log(`  PASS  ${name}`);
  } catch (err) {
    failed += 1;
    failures.push(name);
    console.log(`  FAIL  ${name}`);
    console.log(`        ${String(err).split('\n')[0]}`);
  }
}

const env = await initializeTestEnvironment({
  projectId: 'rules-spec-cash-hold',
  firestore: { rules: readFileSync(rulesPath, 'utf8') },
});

function riderDoc(uid, cashHoldActive) {
  return {
    uid,
    role: 'rider',
    status: 'approved',
    online: true,
    vehicleType: 'bike',
    phone: '+94771111111',
    registrationComplete: true,
    phoneVerified: true,
    cashInHandLkr: cashHoldActive ? 9200 : 1200,
    cashOwedToAdminLkr: cashHoldActive ? 850 : 100,
    cashPendingSettlementLkr: 0,
    cashHoldActive,
  };
}

const openTrip = {
  customerId: CUSTOMER,
  contactPhone: '+94770000000',
  vehicleType: 'bike',
  distanceKm: 4.2,
  estimatedFareLkr: 300,
  fareQuoteId: 'quote1',
  pickup: { lat: 6.9, lng: 79.86, label: 'Pickup' },
  dropoff: { lat: 6.93, lng: 79.85, label: 'Dropoff' },
  status: 'searching',
  openForRiders: true,
  paymentMethod: 'cash',
  paymentStatus: 'pending',
};

const readyOrder = {
  customerId: CUSTOMER,
  vendorId: 'vendorA',
  storeName: 'Shop A',
  subtotal: 1000,
  discount: 0,
  deliveryFee: 200,
  total: 1200,
  items: [{ name: 'Kottu', qty: 1, priceLkr: 1000 }],
  paymentMethod: 'cod',
  status: 'ready',
  openForRiders: true,
  fulfillmentMode: 'delivery',
};

async function seed() {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'customers', CUSTOMER), {
      uid: CUSTOMER,
      role: 'customer',
    });
    await setDoc(doc(db, 'riders', CLEAR_RIDER), riderDoc(CLEAR_RIDER, false));
    await setDoc(doc(db, 'riders', HELD_RIDER), riderDoc(HELD_RIDER, true));
    await setDoc(doc(db, 'trips', 'tripOpen1'), { ...openTrip });
    await setDoc(doc(db, 'trips', 'tripOpen2'), { ...openTrip });
    // Already claimed by the held rider and under way.
    await setDoc(doc(db, 'trips', 'tripInFlight'), {
      ...openTrip,
      status: 'accepted',
      openForRiders: false,
      assignedRiderId: HELD_RIDER,
      riderId: HELD_RIDER,
    });
    await setDoc(doc(db, 'orders', 'orderOpen1'), { ...readyOrder });
    await setDoc(doc(db, 'orders', 'orderOpen2'), { ...readyOrder });
  });
}

const asRider = (uid) => env.authenticatedContext(uid).firestore();

const claimTripPatch = (uid) => ({
  assignedRiderId: uid,
  riderId: uid,
  openForRiders: false,
  status: 'accepted',
  riderAcceptedAt: serverTimestamp(),
  updatedAt: serverTimestamp(),
});

const claimOrderPatch = (uid) => ({
  assignedRiderId: uid,
  riderId: uid,
  openForRiders: false,
  status: 'out_for_delivery',
  riderAcceptedAt: serverTimestamp(),
});

console.log('\n-- trips: claim gate --');
await seed();
await check(
  'rider under the cash limit CAN claim an open ride',
  assertSucceeds(
    updateDoc(doc(asRider(CLEAR_RIDER), 'trips', 'tripOpen1'), claimTripPatch(CLEAR_RIDER)),
  ),
);
await check(
  'rider over the cash limit CANNOT claim an open ride',
  assertFails(
    updateDoc(doc(asRider(HELD_RIDER), 'trips', 'tripOpen2'), claimTripPatch(HELD_RIDER)),
  ),
);

console.log('\n-- orders: claim gate --');
await seed();
await check(
  'rider under the cash limit CAN claim a ready delivery',
  assertSucceeds(
    updateDoc(doc(asRider(CLEAR_RIDER), 'orders', 'orderOpen1'), claimOrderPatch(CLEAR_RIDER)),
  ),
);
await check(
  'rider over the cash limit CANNOT claim a ready delivery',
  assertFails(
    updateDoc(doc(asRider(HELD_RIDER), 'orders', 'orderOpen2'), claimOrderPatch(HELD_RIDER)),
  ),
);

console.log('\n-- in-flight work stays finishable while held --');
await seed();
await check(
  'held rider CAN start their already-accepted ride',
  assertSucceeds(
    updateDoc(doc(asRider(HELD_RIDER), 'trips', 'tripInFlight'), {
      status: 'in_progress',
      startedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  ),
);
await check(
  'held rider CAN complete their in-flight ride',
  assertSucceeds(
    updateDoc(doc(asRider(HELD_RIDER), 'trips', 'tripInFlight'), {
      status: 'completed',
      completedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  ),
);

console.log('\n-- the hold itself is server-only --');
await seed();
await check(
  'rider CANNOT clear their own cash hold',
  assertFails(
    updateDoc(doc(asRider(HELD_RIDER), 'riders', HELD_RIDER), { cashHoldActive: false }),
  ),
);
await check(
  'rider CANNOT rewrite their own cash-in-hand total',
  assertFails(
    updateDoc(doc(asRider(HELD_RIDER), 'riders', HELD_RIDER), { cashInHandLkr: 0 }),
  ),
);
await check(
  'rider CANNOT settle their own cash ledger entry',
  assertFails(
    setDoc(doc(asRider(HELD_RIDER), 'riders', HELD_RIDER, 'cash_ledger', 'ride_x'), {
      type: 'ride_cash',
      status: 'settled',
      cashLkr: 0,
      owedLkr: 0,
    }),
  ),
);
await check(
  'rider CANNOT forge a confirmed settlement for themselves',
  assertFails(
    setDoc(doc(asRider(HELD_RIDER), 'riders', HELD_RIDER, 'cash_settlements', 's1'), {
      riderId: HELD_RIDER,
      amountLkr: 850,
      cashCoveredLkr: 9200,
      status: 'confirmed',
    }),
  ),
);

console.log(`\n${passed} passed, ${failed} failed`);
if (failed > 0) {
  console.log('Failures:', failures.join(', '));
}

await env.cleanup();
process.exit(failed > 0 ? 1 : 0);
