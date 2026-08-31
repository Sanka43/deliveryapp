# MND Cloud Functions

Firebase Functions for **MND Delivery** (`mnd-masterndelivery`).

## Features

| Function | Trigger | Purpose |
|----------|---------|---------|
| `validateCoupon` | HTTPS callable | Server-side coupon validation for checkout |
| `onOrderCreatedValidateCoupon` | Firestore `orders` create | Re-validates discount + increments `usedCount` |
| `onOrderCreatedNotify` | Firestore `orders` create | Inbox row + FCM push |
| `onOrderStatusUpdatedNotify` | Firestore `orders` update | Status change inbox + push |
| `sweepStalePlacedOrders` | Scheduler every 1 min (`asia-south1`) | Vendor accept reminders at 2m/5m; auto-cancel + admin escalate at 7m |
| `paymentWebhook` | HTTPS POST | Order or trip payment callbacks (`orderId` or `tripId`) |
| `placeCashOnDeliveryOrder` | HTTPS callable | Server-priced COD order placement (products, fee, coupon) |
| `lookupVendorOrderCustomer` | HTTPS callable | Vendor phone lookup (linked customer or guest) |
| `placeVendorManualOrder` | HTTPS callable | Vendor phone/manual COD delivery order (starts `confirmed`; actual-trip fee; optional pin; `productsPaid`) |
| `completeDeliveryOrder` | HTTPS callable | Assigned rider finalizes actual-trip delivery fee from path KM and marks `delivered` |
| `adminMarkProductCashRemitted` | HTTPS callable | Admin: rider remitted product cash (`owed` → `remitted_to_admin`) |
| `adminMarkProductCashSettledToShop` | HTTPS callable | Admin: product cash paid to shop (`remitted_to_admin` → `settled_to_shop`) |
| `quoteRideFare` | HTTPS callable | Server-side passenger ride fare quote (single vehicle) |
| `quoteRideFares` | HTTPS callable | Batch fare quotes for Wheel / Bike / Car |
| `confirmCashRide` | HTTPS callable | Create cash trip → `searching` + rider pool |
| `createPayHereCheckout` | HTTPS callable | Create `draft_payment` trip + PayHere form fields |
| `payHereNotify` | HTTPS POST | PayHere notify_url (form-urlencoded) |
| `onOrderDeliveredCreditRider` | Firestore `orders` update | Credits rider wallet/ledger when status → `delivered` |
| `requestRiderWithdrawal` | HTTPS callable | Server-validated rider payout request |
| `blockSyntheticRiderEmailSignup` | Auth `beforeUserCreated` (`us-east1`) | Blocks bare email signup for `@riders.mnd.app` |
| `requestPhoneOtp` | HTTPS callable | Generate OTP + send SMS via SMSlenz |
| `verifyPhoneOtp` | HTTPS callable | Verify OTP → Firebase custom token |

Most callables/triggers: **asia-south1**. Auth blocking: **us-east1** (requires `firebase-functions` >= 7.2.2).

## Setup

```bash
cd functions
npm install
npm run build
```

Seed default coupons (SAVE100, MND10, WELCOME15) into `coupons/{code}`:

```bash
node scripts/seed-coupons.mjs
```

Rotate Auth accounts that still accept the old shared rider temp password
(`MndRiderTempOtp123456!`). Dry-run first, then apply:

```bash
node scripts/rotate-legacy-rider-passwords.mjs
node scripts/rotate-legacy-rider-passwords.mjs --apply
```

Optional: `FIREBASE_WEB_API_KEY=...` (otherwise reads `google-services.json`).

Requires Application Default Credentials:

```bash
firebase login
gcloud auth application-default login
```

Or set `GOOGLE_APPLICATION_CREDENTIALS` to a service-account JSON path.

Project id is read from repo `.firebaserc` (default `mnd-masterndelivery`). Override with `FIREBASE_PROJECT=...`.

## Deploy

Run `npm run build && npm test` first — see the checklist in
[`../CONTRIBUTING.md`](../CONTRIBUTING.md).

From repo root:

```bash
firebase deploy --only functions,firestore:rules,firestore:indexes
```

Set payment secrets (required — webhook fails closed without them):

```bash
firebase functions:secrets:set PAYMENT_WEBHOOK_SECRET
# PayHere (rides)
firebase functions:config:set payhere.merchant_id="..." # or use .env / params
```

SMSlenz phone OTP (customer + rider apps):

```bash
# Secret Manager (required for requestPhoneOtp)
firebase functions:secrets:set SMSLENZ_API_KEY

# Non-secret params (or put in functions/.env before deploy)
# SMSLENZ_USER_ID=2317
# SMSLENZ_SENDER_ID=MN Delivery
```

Local emulator: copy `.env.example` → `.env` and set `SMSLENZ_*`. API key can also live in `.secret.local`.

`PAYMENT_WEBHOOK_SECRET` must be non-empty; unsigned requests are rejected.

Env vars for PayHere: `PAYHERE_MERCHANT_ID`, `PAYHERE_MERCHANT_SECRET`, `PAYHERE_MODE` (`sandbox`|`live`), optional `PAYHERE_RETURN_URL`, `PAYHERE_CANCEL_URL`, `PAYHERE_NOTIFY_URL`.

Webhook URL after deploy:

`https://asia-south1-mnd-masterndelivery.cloudfunctions.net/paymentWebhook`

PayHere notify:

`https://asia-south1-mnd-masterndelivery.cloudfunctions.net/payHereNotify`

Send header `x-mnd-signature: sha256=<hmac-sha256-hex>` of raw JSON body (generic webhook).

## Payment webhook body

```json
{
  "orderId": "abc123",
  "tripId": "optional-trip-id",
  "paymentStatus": "paid",
  "provider": "payhere",
  "transactionId": "TX-001"
}
```

`paymentStatus`: `paid` | `failed` | `refunded` | `pending`

Use either `orderId` (food orders) or `tripId` (passenger rides).
