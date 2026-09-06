// Firestore security rules regression tests for the vendor (mnd_shop) attack
// surface fixed in the Play Store audit. Run from the repo root with:
//   firebase emulators:exec --only firestore "node tools/firestore_rules_tests/run_tests.mjs"
import { readFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';

const here = dirname(fileURLToPath(import.meta.url));
const rulesPath = resolve(here, '../../mnd_customer/firestore.rules');

const VENDOR_A = 'vendorA';
const VENDOR_B = 'vendorB';
const CUSTOMER = 'cust1';

const baseOrder = {
  customerId: CUSTOMER,
  vendorId: VENDOR_A,
  storeName: 'Shop A',
  subtotal: 1000,
  discount: 0,
  deliveryFee: 200,
  total: 1200,
  items: [{ name: 'Kottu', qty: 1, priceLkr: 1000 }],
  paymentMethod: 'cod',
  status: 'placed',
  openForRiders: false,
  fulfillmentMode: 'delivery',
};

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
  projectId: 'rules-spec',
  firestore: { rules: readFileSync(rulesPath, 'utf8') },
});

async function seed() {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'vendors', VENDOR_A), {
      uid: VENDOR_A,
      role: 'vendor',
      vendorStoreId: VENDOR_A,
      name: 'Shop A',
      active: true,
      approvalStatus: 'approved',
    });
    await setDoc(doc(db, 'vendors', VENDOR_B), {
      uid: VENDOR_B,
      role: 'vendor',
      vendorStoreId: VENDOR_B,
      name: 'Shop B',
      active: true,
      approvalStatus: 'approved',
    });
    await setDoc(doc(db, 'customers', CUSTOMER), {
      uid: CUSTOMER,
      role: 'customer',
      displayName: 'Customer One',
    });
    await setDoc(doc(db, 'orders', 'order1'), { ...baseOrder });
    await setDoc(doc(db, 'orders', 'order2'), {
      ...baseOrder,
      status: 'delivered',
      storeRated: false,
    });
  });
}

const vendorADb = () => env.authenticatedContext(VENDOR_A).firestore();
const customerDb = () => env.authenticatedContext(CUSTOMER).firestore();

console.log('\n-- vendors/{uid}: privilege escalation & identity locks --');
await seed();
await check(
  'vendor CANNOT set role: admin on own vendors doc',
  assertFails(updateDoc(doc(vendorADb(), 'vendors', VENDOR_A), { role: 'admin' })),
);
await check(
  'vendor CANNOT re-point own vendorStoreId at another store',
  assertFails(
    updateDoc(doc(vendorADb(), 'vendors', VENDOR_A), { vendorStoreId: VENDOR_B }),
  ),
);
await check(
  'vendor CANNOT change uid on own vendors doc',
  assertFails(updateDoc(doc(vendorADb(), 'vendors', VENDOR_A), { uid: VENDOR_B })),
);
await check(
  'vendor CAN still toggle own store open/closed',
  assertSucceeds(
    updateDoc(doc(vendorADb(), 'vendors', VENDOR_A), { active: false }),
  ),
);
await check(
  'vendor CAN still update own shop profile fields',
  assertSucceeds(
    updateDoc(doc(vendorADb(), 'vendors', VENDOR_A), {
      description: 'Best kottu in town',
    }),
  ),
);

console.log('\n-- vendors: create restrictions --');
await seed();
await check(
  'vendor CANNOT create an arbitrary vendors doc',
  assertFails(
    setDoc(doc(vendorADb(), 'vendors', 'fake-store'), {
      uid: VENDOR_A,
      role: 'v