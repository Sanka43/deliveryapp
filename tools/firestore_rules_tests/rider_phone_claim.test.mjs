// Regression test for the rider phone-claim spoofing fix (riderPhoneClaimMatches
// in mnd_customer/firestore.rules + verifiedPhone claim in functions/src/phoneOtp.ts).
//
// Before the fix, riderPhoneClaimMatches() accepted ANY signed-in phone-OTP
// user writing ANY phone number into their own riders/{uid} doc, because the
// rule OR'd a bare `phoneVerified: true` boolean claim against the document's
// `phone` field. That let a rider who verified their own number squat on a
// victim's number by writing it into their own profile doc.
//
// Run from repo root:
//   firebase emulators:exec --only firestore "node tools/firestore_rules_tests/rider_phone_claim.test.mjs"
import { readFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import { doc, setDoc, Timestamp } from 'firebase/firestore';

const here = dirname(fileURLToPath(import.meta.url));
const rulesPath = resolve(here, '../../mnd_customer/firestore.rules');

const RIDER_UID = 'riderA';
const OWN_PHONE = '+94771111111';
const VICTIM_PHONE = '+94779999999';

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

function riderDoc(uid, phone) {
  return {
    uid,
    fullName: 'Test Rider',
    phone,
    nicNumber: '123456789V',
    profilePhotoUrl: 'https://example.com/p.jpg',
    licensePhotoUrl: 'https://example.com/l.jpg',
    licenseExpiresAt: Timestamp.fromDate(new Date('2030-01-01')),
    vehiclePhotoUrl: 'https://example.com/v.jpg',
    insurancePhotoUrl: 'https://example.com/i.jpg',
    insuranceExpiresAt: Timestamp.fromDate(new Date('2030-01-01')),
    revenueLicensePhotoUrl: 'https://example.com/r.jpg',
    revenueLicenseExpiresAt: Timestamp.fromDate(new Date('2030-01-01')),
    vehicleType: 'bike',
    vehicleNumber: 'ABC1234',
    city: 'Colombo',
    role: 'rider',
    status: 'pending',
    online: false,
    registrationComplete: true,
    phoneVerified: true,
  };
}

const env = await initializeTestEnvironment({
  projectId: 'rules-spec-rider-phone',
  firestore: { rules: readFileSync(rulesPath, 'utf8') },
});

async function seed() {
  await env.clearFirestore();
}

// Simulates the fixed flow: verifyPhoneOtp mints a custom token with
// verifiedPhone bound to the exact number that was OTP-verified.
const freshlyVerifiedCtx = (uid, verifiedPhone) =>
  env.authenticatedContext(uid, { verifiedPhone }).firestore();

// Simulates an ID token that has since refreshed and now carries the
// standard Auth-record phone_number claim.
const establishedPhoneCtx = (uid, phoneNumber) =>
  env.authenticatedContext(uid, { phone_number: phoneNumber }).firestore();

// Simulates the OLD (pre-fix) token shape: only the bare boolean, no
// binding to which number was actually verified. Must now be rejected
// whenever it's the only thing backing a mismatched phone.
const legacyBooleanOnlyCtx = (uid) =>
  env.authenticatedContext(uid, { phoneVerified: true }).firestore();

console.log('\n-- riders/{uid} create: phone-claim binding (spoofing fix) --');

await seed();
await check(
  'rider CAN create own profile when verifiedPhone claim matches the doc phone',
  assertSucceeds(
    setDoc(doc(freshlyVerifiedCtx(RIDER_UID, OWN_PHONE), 'riders', RIDER_UID), riderDoc(RIDER_UID, OWN_PHONE)),
  ),
);

await seed();
await check(
  'rider CANNOT create own profile claiming a different phone than verifiedPhone (squatting)',
  assertFails(
    setDoc(doc(freshlyVerifiedCtx(RIDER_UID, OWN_PHONE), 'riders', RIDER_UID), riderDoc(RIDER_UID, VICTIM_PHONE)),
  ),
);

await seed();
await check(
  'rider CAN create own profile when Auth phone_number claim matches the doc phone',
  assertSucceeds(
    setDoc(doc(establishedPhoneCtx(RIDER_UID, OWN_PHONE), 'riders', RIDER_UID), riderDoc(RIDER_UID, OWN_PHONE)),
  ),
);

await seed();
await check(
  'rider CANNOT create profile with legacy bare phoneVerified boolean + mismatched phone (pre-fix exploit is now blocked)',
  assertFails(
    setDoc(doc(legacyBooleanOnlyCtx(RIDER_UID), 'riders', RIDER_UID), riderDoc(RIDER_UID, VICTIM_PHONE)),
  ),
);

console.log(`\n${passed} passed, ${failed} failed`);
if (failed > 0) {
  console.log('Failures:', failures.join(', '));
}

await env.cleanup();
process.exit(failed > 0 ? 1 : 0);
