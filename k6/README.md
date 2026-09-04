# K6 performance tests

Load tests for the mnd Firebase Cloud Functions backend (project
`mnd-masterndelivery`, region `asia-south1`), run against the **local
Firebase emulator**. Nothing here modifies any existing app/backend code —
this is a standalone, additive test harness.

Most backend logic is exposed as Firebase **callable** functions, which need
a Firebase Auth ID token and a specific request shape. `seed/seed-and-mint-tokens.mjs`
creates synthetic customers/riders/vendor/products/coupon directly in the
emulator and mints ID tokens for them, so no real phone OTP/SMS is involved.

## One-time setup

1. Install k6 — not bundled with this repo:
   ```bash
   winget install k6 --source winget
   ```
   (or see https://k6.io/docs/get-started/installation/ for macOS/Linux)
2. Build the functions once so the emulator has something to serve:
   ```bash
   cd functions && npm install && npm run build
   ```
3. Install the seed script's dependency (separate from `functions/`):
   ```bash
   cd k6 && npm install
   ```

## Running a test

1. Start the emulator **with the Auth emulator included**, using the
   standalone config in this folder (the repo's own `npm run serve` only
   starts `functions,firestore` and the root `firebase.json` has no `auth`
   emulator port configured — `k6/firebase.emulators.json` layers that on
   without touching either existing file):
   ```bash
   firebase --config k6/firebase.emulators.json emulators:start --only functions,firestore,auth --project mnd-masterndelivery
   ```
   Run this from the repo root. Leave it running in its own terminal.
2. In another terminal, seed test data + mint tokens (safe to re-run any
   time — it overwrites the same deterministic docs/users):
   ```bash
   cd k6 && npm run seed
   ```
   This writes `k6/.tokens.json` (gitignored — contains short-lived emulator
   ID tokens, never real credentials).
3. Sanity-check the wiring:
   ```bash
   k6 run k6/scripts/smoke.js
   ```
4. Run a load test:
   ```bash
   k6 run k6/scripts/ride_quote_and_book.js
   k6 run k6/scripts/place_order.js
   k6 run k6/scripts/rider_payouts.js
   ```
   Override the ramp target with `-e MAX_VUS=100`.
5. `driving_route.js` is a smoke check, not a load test — it proxies the
   *real* Google Maps API even via the emulator, so it stays capped at a
   handful of requests (`-e ITERATIONS=5` to change the count).

   Don't try to fake this out for free with a shell-exported
   `GOOGLE_MAPS_KEY` override before starting the emulator — the emulator's
   own `.env` loading takes priority over it, so the real key gets used
   regardless (confirmed directly: it still returned a real, billed route).
   The only real zero-cost option is an env-gated mock branch inside
   `functions/src/mapsProxy.ts` itself — a source change, not something
   this test harness can route around on its own.

## Scripts

| Script | Covers | Notes |
|---|---|---|
| `scripts/smoke.js` | every endpoint below, once | run this first |
| `scripts/ride_quote_and_book.js` | `quoteRideFares` → `confirmCashRide` | the ride-booking hot path |
| `scripts/place_order.js` | `placeCashOnDeliveryOrder` | uses `fulfillmentMode: "selfPickup"` to avoid the real Google Maps distance lookup a delivery order would trigger |
| `scripts/rider_payouts.js` | `requestRiderWithdrawal`, `riderRequestCashSettlement` | withdrawal is the sustained load; settlement only succeeds once per rider until an admin confirms it, so it only runs once per rider in `setup()` |
| `scripts/driving_route.js` | `getDrivingRoute` | smoke-only, real Google Maps billing |

## Tuning the seed data

Env vars for `npm run seed` (all optional):

- `K6_NUM_CUSTOMERS` (default 20)
- `K6_NUM_RIDERS` (default 10)
- `K6_LEDGER_ENTRIES_PER_RIDER` (default 5)
- `K6_WALLET_BALANCE_LKR` (default 5,000,000 — keep this high so
  `rider_payouts.js` can run its full ramp without hitting
  `insufficient-balance`)

## Pointing at a non-emulator environment

Every script reads `BASE_URL` from `k6/config.js`, which defaults to the
emulator's callable URL shape
(`http://localhost:5001/<project>/<region>/<function>`). Override with
`-e BASE_URL=https://asia-south1-mnd-masterndelivery.cloudfunctions.net` to
point at a deployed environment — but note `place_order.js`,
`ride_quote_and_book.js`, and `rider_payouts.js` all write real Firestore
data and mutate real balances, and `seed-and-mint-tokens.mjs` would need to
run against real Firebase Auth (which it currently doesn't support — it only
talks to the Auth emulator). Treat a non-emulator run as a deliberate,
separate decision, not a flag flip.

## Results

k6's default terminal summary is enough for a quick look. For a saved
report:
```bash
k6 run --out json=results/run.json k6/scripts/ride_quote_and_book.js
```
`results/` is gitignored except for the placeholder `.gitkeep`.
