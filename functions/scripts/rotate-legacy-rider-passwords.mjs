/**
 * One-time cleanup: find Auth users that still accept the old shared rider
 * temp password and rotate them to a random unusable password.
 *
 * Why: the old debug OTP / public callable path set every account to
 * `MndRiderTempOtp123456!`. Even after the client fallback was removed, those
 * accounts remain takeover targets until the password is changed.
 *
 * Affected riders can still sign in with real phone OTP. Password login will
 * fail until they re-register / set a new password via a future reset flow.
 *
 * Prerequisites — any ONE of:
 *   - firebase login              (Firebase CLI credentials are reused)
 *   - gcloud auth application-default login
 *   - GOOGLE_APPLICATION_CREDENTIALS=<service-account.json>
 *
 * Usage (dry-run first):
 *   cd functions
 *   node scripts/rotate-legacy-rider-passwords.mjs
 *   node scripts/rotate-legacy-rider-passwords.mjs --apply
 *
 * Optional env:
 *   FIREBASE_PROJECT=mnd-masterndelivery
 *   FIREBASE_WEB_API_KEY=<Web API key from Firebase console / google-services>
 *   LEGACY_RIDER_PASSWORD=MndRiderTempOtp123456!
 */
import {createHash, randomBytes} from "crypto";
import {existsSync, readFileSync} from "fs";
import {homedir} from "os";
import {dirname, join} from "path";
import {fileURLToPath} from "url";
import {
  applicationDefault,
  getApps,
  initializeApp,
  refreshToken,
} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";

// Public OAuth client of the open-source Firebase CLI (not a secret) — lets
// this script reuse the developer's `firebase login` session.
const FIREBASE_CLI_CLIENT_ID =
  "563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com";
const FIREBASE_CLI_CLIENT_SECRET = "j9iVZfS8kkCEFUPaAeJV0sAi";

const __dirname = dirname(fileURLToPath(import.meta.url));
const LEGACY_PASSWORD =
  (process.env.LEGACY_RIDER_PASSWORD ?? "MndRiderTempOtp123456!").trim();
const APPLY = process.argv.includes("--apply");
const RIDER_EMAIL_RE = /^rider\.\d+@riders\.mnd\.app$/i;

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

function resolveWebApiKey() {
  if (process.env.FIREBASE_WEB_API_KEY?.trim()) {
    return process.env.FIREBASE_WEB_API_KEY.trim();
  }
  // Prefer rider app google-services (Android client).
  const candidates = [
    join(__dirname, "..", "..", "mnd_rider", "android", "app", "google-services.json"),
    join(__dirname, "..", "..", "mnd_customer", "android", "app", "google-services.json"),
  ];
  for (const path of candidates) {
    try {
      const raw = readFileSync(path, "utf8");
      const parsed = JSON.parse(raw);
      const key = parsed?.client?.[0]?.api_key?.[0]?.current_key;
      if (typeof key === "string" && key.trim()) {
        return key.trim();
      }
    } catch {
      // try next
    }
  }
  throw new Error(
    "Set FIREBASE_WEB_API_KEY (Firebase Console → Project settings → Web API key).",
  );
}

async function acceptsLegacyPassword(apiKey, email) {
  const url =
    `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${apiKey}`;
  const res = await fetch(url, {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify({
      email,
      password: LEGACY_PASSWORD,
      returnSecureToken: true,
    }),
  });
  if (res.ok) {
    return true;
  }
  let body = {};
  try {
    body = await res.json();
  } catch {
    // ignore
  }
  const message = String(body?.error?.message ?? "");
  // Wrong password / unknown user → not a legacy-password account.
  if (
    message.includes("INVALID_PASSWORD") ||
    message.includes("INVALID_LOGIN_CREDENTIALS") ||
    message.includes("EMAIL_NOT_FOUND") ||
    message.includes("USER_DISABLED")
  ) {
    return false;
  }
  throw new Error(`Identity Toolkit error for ${email}: ${message || res.status}`);
}

function randomPassword() {
  // High-entropy unusable password; users recover via phone OTP, not this value.
  return `rotated_${randomBytes(24).toString("base64url")}_${createHash("sha256")
    .update(String(Date.now()))
    .digest("hex")
    .slice(0, 12)}`;
}

function resolveCredential() {
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS?.trim()) {
    return applicationDefault();
  }
  const gcloudAdcCandidates = [
    process.env.APPDATA ?
      join(process.env.APPDATA, "gcloud", "application_default_credentials.json") :
      null,
    join(homedir(), ".config", "gcloud", "application_default_credentials.json"),
  ].filter(Boolean);
  if (gcloudAdcCandidates.some((path) => existsSync(path))) {
    return applicationDefault();
  }

  // Fall back to the Firebase CLI's stored login (firebase login).
  const configstore = join(homedir(), ".config", "configstore", "firebase-tools.json");
  if (existsSync(configstore)) {
    try {
      const parsed = JSON.parse(readFileSync(configstore, "utf8"));
      const token = parsed?.tokens?.refresh_token;
      if (typeof token === "string" && token.trim()) {
        console.log("Using Firebase CLI login credentials (firebase login).");
        return refreshToken({
          type: "authorized_user",
          client_id: FIREBASE_CLI_CLIENT_ID,
          client_secret: FIREBASE_CLI_CLIENT_SECRET,
          refresh_token: token.trim(),
        });
      }
    } catch {
      // fall through
    }
  }

  throw new Error(
    "No Google credentials found. Run `firebase login`, or " +
    "`gcloud auth application-default login`, or set GOOGLE_APPLICATION_CREDENTIALS.",
  );
}

const projectId = resolveProjectId();
const apiKey = resolveWebApiKey();

if (getApps().length === 0) {
  initializeApp({projectId, credential: resolveCredential()});
}

const auth = getAuth();

console.log(`Project: ${projectId}`);
console.log(`Mode: ${APPLY ? "APPLY (will rotate)" : "DRY-RUN (no writes)"}`);
console.log(`Looking for emails matching ${RIDER_EMAIL_RE}`);

let scanned = 0;
let legacyHits = 0;
let rotated = 0;
let pageToken;

do {
  const page = await auth.listUsers(1000, pageToken);
  for (const user of page.users) {
    const email = (user.email ?? "").trim();
    if (!RIDER_EMAIL_RE.test(email)) {
      continue;
    }
    scanned += 1;
    const hit = await acceptsLegacyPassword(apiKey, email);
    if (!hit) {
      continue;
    }
    legacyHits += 1;
    console.log(`LEGACY  uid=${user.uid}  email=${email}  phone=${user.phoneNumber ?? "-"}`);
    if (!APPLY) {
      continue;
    }
    await auth.updateUser(user.uid, {password: randomPassword()});
    rotated += 1;
    console.log(`ROTATED uid=${user.uid}`);
  }
  pageToken = page.pageToken;
} while (pageToken);

console.log("---");
console.log(`Rider-pattern users scanned: ${scanned}`);
console.log(`Still accepting legacy password: ${legacyHits}`);
console.log(`Rotated: ${rotated}`);
if (!APPLY && legacyHits > 0) {
  console.log("Re-run with --apply to rotate those accounts.");
}
