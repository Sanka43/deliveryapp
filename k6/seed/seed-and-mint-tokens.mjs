/**
 * One-shot seeder for the k6 performance suite. Run this AFTER starting the
 * Firebase emulator (functions + firestore + auth) and BEFORE running any
 * k6 script:
 *
 *   node seed/seed-and-mint-tokens.mjs
 *
 * It creates synthetic customer + rider Auth users directly in the Auth
 * emulator (no real phone OTP/SMS involved), mints a Firebase Auth ID token
 * for each by creating a custom token and exchanging it against the Auth
 * emulator's REST API, seeds one active test vendor with a few in-stock
 * products and one active coupon, and seeds each rider a wallet balance +
 * open cash-ledger entries so the payout endpoints have something to act on.
 *
 * Everything is written with deterministic ids, so re-running this script is
 * safe and just refreshes the seeded state + mints fresh (short-lived) ID
 * tokens.
 *
 * Output: ../.tokens.json, read by k6/lib/users.js at test time.
 */
import { readFileSync, writeFileSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore, GeoPoint } from 'firebase-admin/firestore';

const __dirname = dirname(fileURLToPath(import.meta.url));

const NUM_CUSTOMERS = Number(process.env.K6_NUM_CUSTOMERS ?? 20);
const NUM_RIDERS = Number(process.env.K6_NUM_RIDERS ?? 10);
const LEDGER_ENTRIES_PER_RIDER = Number(process.env.K6_LEDGER_ENTRIES_PER_RIDER ?? 5);
const LEDGER_ENTRY_LKR = 200;
const WALLET_BALANCE_LKR = Number(process.env.K6_WALLET_BALANCE_LKR ?? 5_000_000);
const VENDOR_ID = 'k6-load-test-vendor';
const COUPON_CODE = 'K6LOAD10';

function resolveProjectId() {
  if (process.env.PROJECT_ID?.trim()) {
    return process.env.PROJECT_ID.trim();
  }
  try {
    const raw = readFileSync(join(__dirname, '..', '..', '.firebaserc'), 'utf8');
    const id = JSON.parse(raw)?.projects?.default;
    if (typeof id === 'string' && id.trim()) {
      return id.trim();
    }
  } catch {
    // fall through to hardcoded default
  }
  return 'mnd-masterndelivery';
}

const PROJECT_ID = resolveProjectId();
const AUTH_EMULATOR_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';
const FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';

// Must be set before firebase-admin touches Auth/Firestore, so the SDK talks
// to the emulator instead of production.
process.env.FIREBASE_AUTH_EMULATOR_HOST = AUTH_EMULATOR_HOST;
process.env.FIRESTORE_EMULATOR_HOST = FIRESTORE_EMULATOR_HOST;

initializeApp({ projectId: PROJECT_ID });
const auth = getAuth();
const db = getFirestore();

async function ensureUser(uid) {
  try {
    await auth.createUser({ uid });
  } catch (err) {
    if (err?.code !== 'auth/uid-already-exists') {
      throw err;
    }
  }
}

async function mintIdToken(uid) {
  const customToken = await auth.createCustomToken(uid);
  const res = await fetch(
    `http://${AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=fake-api-key`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token: customToken, returnSecureToken: true }),
    },
  );
  const body = await res.json();
  if (!res.ok || !body.idToken) {
    throw new Error(`Failed to mint ID token for ${uid}: ${JSON.stringify(body)}`);
  }
  return body.idToken;
}

async function seedCustomers() {
  const customers = [];
  for (let i = 1; i <= NUM_CUSTOMERS; i++) {
    const uid = `k6-customer-${i}`;
    await ensureUser(uid);
    const idToken = await mintIdToken(uid);

    // createJobPost requires a customers/{uid} doc to exist, with a real
    // jobPostCredits balance (each post consumes one) — seeded very high so
    // job_postings.js can sustain a full load-test ramp, same reasoning as
    // the rider wallet balance below.
    await db.collection('customers').doc(uid).set(
      {
        uid,
        displayName: `K6 Customer ${i}`,
        jobsBlocked: false,
        jobPostCredits: 1_000_000,
      },
      { merge: true },
    );

    customers.push({ uid, idToken });
  }
  console.log(`Seeded ${customers.length} customer users (each with a job-post credit balance).`);
  return customers;
}

async function seedRiders() {
  const riders = [];
  for (let i = 1; i <= NUM_RIDERS; i++) {
    const uid = `k6-rider-${i}`;
    await ensureUser(uid);
    const idToken = await mintIdToken(uid);

    const riderRef = db.collection('riders').doc(uid);
    await riderRef.set(
      {
        uid,
        fullName: `K6 Test Rider ${i}`,
        phone: `+9477${String(1000000 + i).slice(0, 7)}`,
        vehicleType: 'bike',
        vehicleNumber: `WP-K6-${String(i).padStart(3, '0')}`,
        city: 'Colombo',
        role: 'rider',
        status: 'approved',
        online: false,
        registrationComplete: true,
        phoneVerified: true,
      },
      { merge: true },
    );

    await riderRef.collection('wallet').doc('summary').set({
      balanceLkr: WALLET_BALANCE_LKR,
      pendingWithdrawalLkr: 0,
      lifetimeEarnedLkr: WALLET_BALANCE_LKR,
      lifetimeWithdrawnLkr: 0,
      updatedAt: FieldValue.serverTimestamp(),
    });

    // Open cash-ledger entries so riderRequestCashSettlement has something
    // to hand over. NOTE: that endpoint only succeeds once per rider until
    // an admin confirms the settlement (not simulated here), so it isn't
    // suited for sustained per-iteration load — see scripts/rider_payouts.js.
    for (let j = 1; j <= LEDGER_ENTRIES_PER_RIDER; j++) {
      await riderRef
        .collection('cash_ledger')
        .doc(`k6-seed-${j}`)
        .set({
          status: 'open',
          type: 'order_cash',
          orderId: `k6-seed-order-${i}-${j}`,
          cashLkr: LEDGER_ENTRY_LKR,
          owedLkr: LEDGER_ENTRY_LKR,
          breakdown: {
            productCashLkr: LEDGER_ENTRY_LKR,
            serviceChargeLkr: 0,
            rideCommissionLkr: 0,
          },
          createdAt: FieldValue.serverTimestamp(),
        });
    }

    riders.push({ uid, idToken });
  }
  console.log(`Seeded ${riders.length} rider users (wallet + open cash-ledger entries).`);
  return riders;
}

async function seedVendor() {
  await db.collection('vendors').doc(VENDOR_ID).set(
    {
      name: 'K6 Load Test Store',
      active: true,
      addressLine: '1 Load Test Road',
      city: 'Colombo',
      location: new GeoPoint(6.9271, 79.8612),
    },
    { merge: true },
  );

  const productIds = [];
  const products = [
    { id: 'k6-product-1', name: 'K6 Test Item 1', price: 500 },
    { id: 'k6-product-2', name: 'K6 Test Item 2', price: 750 },
    { id: 'k6-product-3', name: 'K6 Test Item 3', price: 1200 },
  ];
  for (const p of products) {
    await db.collection('products').doc(p.id).set(
      {
        storeId: VENDOR_ID,
        name: p.name,
        price: p.price,
        active: true,
        manageStock: false,
      },
      { merge: true },
    );
    productIds.push(p.id);
  }
  console.log(`Seeded vendor ${VENDOR_ID} with ${productIds.length} products.`);
  return { vendorId: VENDOR_ID, productIds };
}

async function seedVendorOwners() {
  const count = Number(process.env.K6_NUM_VENDOR_OWNERS ?? 20);
  const vendorOwners = [];
  for (let i = 1; i <= count; i++) {
    const uid = `k6-vendor-owner-${i}`;
    await ensureUser(uid);
    const idToken = await mintIdToken(uid);

    // A vendors/{uid} doc where the doc id IS the caller's own uid is the
    // simplest path resolveCallerVendorStore() accepts (see placeOrder.ts) —
    // no separate customers/{uid}.vendorStoreId link needed.
    await db.collection('vendors').doc(uid).set(
      {
        uid,
        name: `K6 Vendor Owner ${i}`,
        active: true,
        addressLine: '1 Load Test Road',
        city: 'Colombo',
      },
      { merge: true },
    );

    vendorOwners.push({ uid, idToken });
  }
  console.log(`Seeded ${vendorOwners.length} vendor-owner users (each their own active store).`);
  return vendorOwners;
}

async function seedAdmin() {
  const uid = 'k6-admin';
  await ensureUser(uid);
  const idToken = await mintIdToken(uid);

  // assertAdmin() has two independent implementations in this codebase
  // (adminAuth.ts checks users/{uid}.role OR customers/{uid}.role;
  // jobs.ts's own copy checks only customers/{uid}.role) — a customers/{uid}
  // doc with role:"admin" satisfies both.
  await db.collection('customers').doc(uid).set(
    { uid, displayName: 'K6 Admin', role: 'admin' },
    { merge: true },
  );

  console.log(`Seeded admin user ${uid}.`);
  return { uid, idToken };
}

async function seedCoupon() {
  await db.collection('coupons').doc(COUPON_CODE).set(
    {
      code: COUPON_CODE,
      discountType: 'percent',
      value: 10,
      active: true,
      maxDiscountLkr: 500,
    },
    { merge: true },
  );
  console.log(`Seeded coupon ${COUPON_CODE}.`);
  return COUPON_CODE;
}

async function main() {
  console.log(`Seeding against project "${PROJECT_ID}" via emulators`);
  console.log(`  Auth:      ${AUTH_EMULATOR_HOST}`);
  console.log(`  Firestore: ${FIRESTORE_EMULATOR_HOST}`);

  const [customers, riders, vendorOwners, admin, vendor, couponCode] = [
    await seedCustomers(),
    await seedRiders(),
    await seedVendorOwners(),
    await seedAdmin(),
    await seedVendor(),
    await seedCoupon(),
  ];

  const outPath = join(__dirname, '..', '.tokens.json');
  writeFileSync(
    outPath,
    JSON.stringify(
      { projectId: PROJECT_ID, customers, riders, vendorOwners, admin, vendor, couponCode },
      null,
      2,
    ),
  );
  console.log(`Wrote ${outPath}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
