// Regression test for the coupons/{code} lockdown in
// mnd_customer/firestore.rules (see functions/src/coupons.ts,
// functions/src/placeOrder.ts). Coupon codes and their rules (discount,
// expiry, usage limits) must never be readable directly by a customer —
// they're only ever resolved through the `validateCoupon` callable or
// order placement, both running under the Admin SDK which bypasses these
// rules entirely. Only the admin web dashboard manages coupons directly.
//
// Run from repo root:
//   firebase emulators:exec --only firestore "node tools/firestore_rules_tests/coupons.test.mjs"
import { readFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, deleteDoc } from 'firebase/firestore';

const here = dirname(fileURLToPath(import.meta.url));
const rulesPath = resolve(here, '../../mnd_customer/firestore.rules');

const ADMIN = 'admin1';
const CUSTOMER = 'cust1';
const CODE = 'WELCOME15';

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
  projectId: 'rules-spec-coupons',
  firestore: { rules: readFileSync(rulesPath, 'utf8') },
});

async function seed() {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'customers', ADMIN), {
      uid: ADMIN,
      role: 'admin',
      displayName: 'Admin',
    });
    await setDoc(doc(db, 'customers', CUSTOMER), {
      uid: CUSTOMER,
      role: 'customer',
      displayName: 'Customer One',
    });
    await setDoc(doc(db, 'coupons', CODE), {
      code: CODE,
      discountType: 'percent',
      value: 15,
      active: true,
      minSubtotalLkr: 500,
    });
    await setDoc(doc(db, 'coupons', CODE, 'usage_shards', '0'), { count: 3 });
    await setDoc(doc(db, 'coupons', CODE, 'customer_usage', CUSTOMER), {
      count: 1,
    });
  });
}

const adminDb = () => env.authenticatedContext(ADMIN).firestore();
const customerDb = () => env.authenticatedContext(CUSTOMER).firestore();
const anonDb = () => env.unauthenticatedContext().firestore();

console.log('\n-- coupons/{code}: never directly readable/writable by customers --');
await seed();

await check(
  'signed-out CANNOT read a coupon doc',
  assertFails(getDoc(doc(anonDb(), 'coupons', CODE))),
);
await check(
  'customer CANNOT read a coupon doc',
  assertFails(getDoc(doc(customerDb(), 'coupons', CODE))),
);
await check(
  'customer CANNOT create a coupon doc (e.g. a decompiled/guessed code)',
  assertFails(
    setDoc(doc(customerDb(), 'coupons', 'FREE1000'), {
      code: 'FREE1000',
      discountType: 'flat',
      value: 1000,
      active: true,
    }),
  ),
);
await check(
  'customer CANNOT update an existing coupon (e.g. raise the value)',
  assertFails(updateDoc(doc(customerDb(), 'coupons', CODE), { value: 9999 })),
);
await check(
  'customer CANNOT delete a coupon',
  assertFails(deleteDoc(doc(customerDb(), 'coupons', CODE))),
);
await check(
  'customer CANNOT read usage shard counters',
  assertFails(getDoc(doc(customerDb(), 'coupons', CODE, 'usage_shards', '0'))),
);
await check(
  'customer CANNOT write their own per-customer usage counter',
  assertFails(
    setDoc(doc(customerDb(), 'coupons', CODE, 'customer_usage', CUSTOMER), {
      count: 0,
    }),
  ),
);
await check(
  'admin CAN read a coupon doc (dashboard listing)',
  assertSucceeds(getDoc(doc(adminDb(), 'coupons', CODE))),
);
await check(
  'admin CAN create a new coupon',
  assertSucceeds(
    setDoc(doc(adminDb(), 'coupons', 'ADMIN20'), {
      code: 'ADMIN20',
      discountType: 'percent',
      value: 20,
      active: true,
    }),
  ),
);
await check(
  'admin CAN update an existing coupon',
  assertSucceeds(updateDoc(doc(adminDb(), 'coupons', CODE), { active: false })),
);
await check(
  'admin CAN delete a coupon',
  assertSucceeds(deleteDoc(doc(adminDb(), 'coupons', CODE))),
);
await check(
  'even admin CANNOT hand-write usage shard counters (Functions-only)',
  assertFails(
    setDoc(doc(adminDb(), 'coupons', CODE, 'usage_shards', '0'), { count: 99 }),
  ),
);

console.log(`\n${passed} passed, ${failed} failed`);
if (failed > 0) {
  console.log('Failed checks:', failures.join(', '));
  process.exitCode = 1;
}
await env.cleanup();
