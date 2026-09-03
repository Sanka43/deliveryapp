/**
 * Seed / patch a rider Firestore doc for emulator QA via Firestore REST.
 *
 * Usage:
 *   node scripts/seed-e2e-rider.mjs --uid <firebaseAuthUid> [--phone +94759193986]
 */
import {existsSync, readFileSync} from "fs";
import {homedir} from "os";
import {dirname, join} from "path";
import {fileURLToPath} from "url";

const FIREBASE_CLI_CLIENT_ID =
  "563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com";
const FIREBASE_CLI_CLIENT_SECRET = "j9iVZfS8kkCEFUPaAeJV0sAi";
const __dirname = dirname(fileURLToPath(import.meta.url));

function resolveProjectId() {
  if (process.env.FIREBASE_PROJECT?.trim()) {
    return process.env.FIREBASE_PROJECT.trim();
  }
  try {
    const raw = readFileSync(join(__dirname, "..", "..", ".firebaserc"), "utf8");
    const id = JSON.parse(raw)?.projects?.default;
    if (typeof id === "string" && id.trim()) {
      return id.trim();
    }
  } catch {
    // fall through
  }
  return "mnd-masterndelivery";
}

async function accessTokenFromFirebaseCli() {
  const configstore = join(homedir(), ".config", "configstore", "firebase-tools.json");
  if (!existsSync(configstore)) {
    throw new Error("Run `firebase login` first.");
  }
  const refresh = JSON.parse(readFileSync(configstore, "utf8"))?.tokens?.refresh_token;
  if (!refresh) {
    throw new Error("No refresh token; run `firebase login`.");
  }
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: {"Content-Type": "application/x-www-form-urlencoded"},
    body: new URLSearchParams({
      client_id: FIREBASE_CLI_CLIENT_ID,
      client_secret: FIREBASE_CLI_CLIENT_SECRET,
      refresh_token: refresh,
      grant_type: "refresh_token",
    }),
  });
  const body = await res.json();
  if (!res.ok) {
    throw new Error(`Token exchange failed: ${JSON.stringify(body)}`);
  }
  return body.access_token;
}

function str(v) {
  return {stringValue: String(v)};
}
function bool(v) {
  return {booleanValue: Boolean(v)};
}
function num(v) {
  return {doubleValue: Number(v)};
}

const uidIdx = process.argv.indexOf("--uid");
const phoneIdx = process.argv.indexOf("--phone");
const uid = uidIdx !== -1 ? process.argv[uidIdx + 1] : null;
const phone = phoneIdx !== -1 ? process.argv[phoneIdx + 1] : "+94759193986";
if (!uid) {
  throw new Error("Usage: --uid <firebaseAuthUid>");
}

const projectId = resolveProjectId();
const token = await accessTokenFromFirebaseCli();
const digits = phone.replace(/\D/g, "");
const email = `rider.${digits}@riders.mnd.app`;

const riderFields = {
  uid: str(uid),
  fullName: str("E2E Test Rider"),
  phone: str(phone),
  nicNumber: str("200012345678"),
  profilePhotoUrl: str("https://via.placeholder.com/200"),
  licensePhotoUrl: str("https://via.placeholder.com/200"),
  vehicleType: str("bike"),
  vehicleNumber: str("WP-E2E-001"),
  city: str("Colombo"),
  email: str(email),
  role: str("rider"),
  status: str("approved"),
  online: bool(false),
  registrationComplete: bool(true),
  phoneVerified: bool(true),
};

const walletFields = {
  balanceLkr: num(1500),
  pendingWithdrawalLkr: num(0),
  lifetimeEarnedLkr: num(1500),
  lifetimeWithdrawnLkr: num(0),
};

async function patchDoc(path, fields) {
  const url =
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${path}` +
    `?${Object.keys(fields).map((k) => `updateMask.fieldPaths=${encodeURIComponent(k)}`).join("&")}`;
  const res = await fetch(url, {
    method: "PATCH",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({fields}),
  });
  const body = await res.json();
  if (!res.ok) {
    throw new Error(`PATCH ${path} failed: ${JSON.stringify(body)}`);
  }
  return body;
}

await patchDoc(`riders/${uid}`, riderFields);
await patchDoc(`riders/${uid}/wallet/summary`, walletFields);
console.log(`Seeded approved rider ${uid} (${phone}) on ${projectId}`);
