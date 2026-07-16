/**
 * Seeds default MND coupons into Firestore.
 *
 * Prerequisites:
 *   firebase login
 *   gcloud auth application-default login
 *   (or set GOOGLE_APPLICATION_CREDENTIALS to a service-account JSON)
 *
 * Usage:
 *   cd functions && npm run build
 *   node scripts/seed-coupons.mjs
 *
 * Optional env:
 *   FIREBASE_PROJECT=mnd-masterndelivery
 */
import { readFileSync } from "fs";
import { dirname, join } from "path";
import { fileURLToPath } from "url";
import { initializeApp, getApps } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { DEFAULT_COUPONS } from "../lib/seedCoupons.js";

const __dirname = dirname(fileURLToPath(import.meta.url));

function resolveProjectId() {
  if (process.env.FIREBASE_PROJECT?.trim()) {
    return process.env.FIREBASE_PROJECT.trim();
  }
  if (process.env.GCLOUD_PROJECT?.trim()) {
    return process.env.GCLOUD_PROJECT.trim();
  }
  try {
    const firebasercPath = join(__dirname, "..", "..", ".firebaserc");
    const raw = readFileSync(firebasercPath, "utf8");
    const parsed = JSON.parse(raw);
    const id = parsed?.projects?.default;
    if (typeof id === "string" && id.trim()) {
      return id.trim();
    }
  } catch {
    // fall through
  }
  return "mnd-masterndelivery";
}

const projectId = resolveProjectId();

if (getApps().length === 0) {
  initializeApp({ projectId });
}

const db = getFirestore();

console.log(`Seeding coupons into project: ${projectId}`);

for (const coupon of DEFAULT_COUPONS) {
  await db.collection("coupons").doc(coupon.id).set(coupon, { merge: true });
  console.log(`Seeded coupon ${coupon.id}`);
}

console.log("Done.");
