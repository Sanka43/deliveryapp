/**
 * Set Firebase Storage bucket CORS so Flutter CanvasKit on mnd.lk can decode images.
 *
 * Usage (from mnd_customer or functions):
 *   node tool/set_storage_cors.mjs
 *
 * Auth: firebase login (refresh token) or GOOGLE_APPLICATION_CREDENTIALS / gcloud ADC.
 */
import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { GoogleAuth, UserRefreshClient } from "google-auth-library";

const __dirname = dirname(fileURLToPath(import.meta.url));
const PROJECT = "mnd-masterndelivery";
const BUCKETS = [
  "mnd-masterndelivery.firebasestorage.app",
  "mnd-masterndelivery.appspot.com",
];

// Same public OAuth client used by the Firebase CLI.
const FIREBASE_CLI_CLIENT_ID =
  "563584335869-fgrhgmd47bqnek0gukl1ukvfddfnnlck.apps.googleusercontent.com";
const FIREBASE_CLI_CLIENT_SECRET = "j9iVZfS8kkCEFUPaAeJV0sAi";

function loadCorsConfig() {
  const path = join(__dirname, "..", "storage-cors.json");
  return JSON.parse(readFileSync(path, "utf8"));
}

function firebaseCliRefreshToken() {
  const candidates = [
    join(homedir(), ".config", "configstore", "firebase-tools.json"),
    process.env.APPDATA
      ? join(process.env.APPDATA, "configstore", "firebase-tools.json")
      : null,
  ].filter(Boolean);
  for (const path of candidates) {
    if (!existsSync(path)) continue;
    try {
      const parsed = JSON.parse(readFileSync(path, "utf8"));
      const token = parsed?.tokens?.refresh_token;
      if (typeof token === "string" && token.trim()) {
        return token.trim();
      }
    } catch {
      // continue
    }
  }
  return null;
}

async function getAccessToken() {
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS?.trim()) {
    const auth = new GoogleAuth({
      scopes: ["https://www.googleapis.com/auth/devstorage.full_control"],
    });
    const client = await auth.getClient();
    const token = await client.getAccessToken();
    if (!token.token) throw new Error("ADC returned empty access token");
    return token.token;
  }

  const refresh = firebaseCliRefreshToken();
  if (!refresh) {
    throw new Error(
      "No credentials. Run `firebase login` or set GOOGLE_APPLICATION_CREDENTIALS.",
    );
  }
  const client = new UserRefreshClient(
    FIREBASE_CLI_CLIENT_ID,
    FIREBASE_CLI_CLIENT_SECRET,
    refresh,
  );
  const { token } = await client.getAccessToken();
  if (!token) throw new Error("Firebase CLI refresh returned empty access token");
  return token;
}

async function patchBucketCors(bucket, cors, accessToken) {
  const url =
    `https://storage.googleapis.com/storage/v1/b/${encodeURIComponent(bucket)}` +
    `?fields=name,cors`;
  const res = await fetch(url, {
    method: "PATCH",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ cors }),
  });
  const text = await res.text();
  if (!res.ok) {
    throw new Error(`PATCH ${bucket} failed (${res.status}): ${text}`);
  }
  console.log(`OK ${bucket}`);
  console.log(text);
}

async function main() {
  const cors = loadCorsConfig();
  console.log(`Project ${PROJECT}; applying CORS to ${BUCKETS.length} bucket name(s)…`);
  const accessToken = await getAccessToken();
  let ok = 0;
  for (const bucket of BUCKETS) {
    try {
      await patchBucketCors(bucket, cors, accessToken);
      ok++;
    } catch (e) {
      console.warn(String(e?.message || e));
    }
  }
  if (ok === 0) {
    process.exitCode = 1;
    console.error("No buckets updated.");
  }
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
