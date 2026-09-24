// Rules regression tests for customer profile setup (mnd_customer
// complete-profile step + CustomerProfileRepository.updateProfile).
//
// Run from repo root:
//   firebase emulators:exec --only firestore "node tools/firestore_rules_tests/customer_profile.test.mjs"
import { readFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import { doc, setDoc, serverTimestamp } from 'firebase/firestore';

const here = dirname(fileURLToPath(import.meta.url));
const rulesPath = resolve(here, '../../mnd_customer/firestore.rules');

const NEW_CUSTOMER = 'newCust';
const LEGACY = 'legacyCust';
const OTHER = 'otherCust';

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
    // Pre-uid/role doc shape from early builds.
    await setDoc(doc(db, 'customers', LEGACY), {
      displayName: null,
      phoneNumber: '+94771234567',
    });
    await setDoc(doc(db, 'customers', OTHER), {
      uid: OTHER,
      role: 'customer',
      displayName: 'Other',
    });
  });
}

const dbFor = (uid) => env.authenticatedContext(uid).firestore();
const merge = { merge: true };

console.log('\n-- customers/{uid}: profile setup when the doc is missing --');
await seed();
await check(
  'name-only merge on a missing doc is rejected (why updateProfile adds uid/role)',
  assertFails(
    setDoc(
      doc(dbFor(NEW_CUSTOMER), 'customers', NEW_CUSTOMER),
      { displayName: 'Kamal Perera', updatedAt: serverTimestamp() },
      merge,
    ),
  ),
);
await check(
  'updateProfile create payload (uid + role customer) succeeds',
  assertSucceeds(
    setDoc(
      doc(dbFor(NEW_CUSTOMER), 'customers', NEW_CUSTOMER),
      {
        uid: NEW_CUSTOMER,
        role: 'customer',
        displayName: 'Kamal Perera',
        phoneNumber: '+94770000000',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      },
      merge,
    ),
  ),
);
await check(
  'customer CANNOT create own doc as admin',
  assertFails(
    setDoc(doc(dbFor('sneaky'), 'customers', 'sneaky'), {
      uid: 'sneaky',
      role: 'admin',
      displayName: 'X',
    }),
  ),
);

console.log('\n-- customers/{uid}: legacy docs without uid/role --');
await seed();
await check(
  'legacy owner CAN set name/email',
  assertSucceeds(
    setDoc(
      doc(dbFor(LEGACY), 'customers', LEGACY),
      { displayName: 'Nimal', email: 'n@example.com', updatedAt: serverTimestamp() },
      merge,
    ),
  ),
);
await check(
  'legacy owner CANNOT add role: admin',
  assertFails(
    setDoc(doc(dbFor(LEGACY), 'customers', LEGACY), { role: 'admin' }, merge),
  ),
);
await check(
  'legacy owner CANNOT add a uid',
  assertFails(
    setDoc(doc(dbFor(LEGACY), 'customers', LEGACY), { uid: LEGACY }, merge),
  ),
);

console.log('\n-- customers/{uid}: identity locks still hold --');
await seed();
await check(
  'customer CANNOT change own role',
  assertFails(
    setDoc(doc(dbFor(OTHER), 'customers', OTHER), { role: 'rider' }, merge),
  ),
);
await check(
  "customer CANNOT write another customer's doc",
  assertFails(
    setDoc(doc(dbFor(NEW_CUSTOMER), 'customers', OTHER), { displayName: 'Hacked' }, merge),
  ),
);

await env.cleanup();
console.log(`\n${passed} passed, ${failed} failed`);
if (failed > 0) {
  console.log('Failures:');
  for (const f of failures) console.log(`  - ${f}`);
  process.exit(1);
}
