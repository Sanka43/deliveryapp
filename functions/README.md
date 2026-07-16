# MND Cloud Functions

Firebase Functions for **MND Delivery** (`mnd-masterndelivery`).

## Features

| Function | Trigger | Purpose |
|----------|---------|---------|
| `validateCoupon` | HTTPS callable | Server-side coupon validation for checkout |
| `onOrderCreatedValidateCoupon` | Firestore `orders` create | Re-validates discount + increments `usedCount` |
| `onOrderCreatedNotify` | Firestore `orders` create | Inbox row + FCM push |
| `onOrderStatusUpdatedNotify` | Firestore `orders` update | Status change inbox + push |
| `paymentWebhook` | HTTPS POST | Card/wallet payment provider callbacks |

Region: **asia-south1** (matches callable client in Flutter).

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

Requires Application Default Credentials:

```bash
firebase login
gcloud auth application-default login
```

Or set `GOOGLE_APPLICATION_CREDENTIALS` to a service-account JSON path.

Project id is read from repo `.firebaserc` (default `mnd-masterndelivery`). Override with `FIREBASE_PROJECT=...`.

## Deploy

From repo root:

```bash
firebase deploy --only functions,firestore:rules,firestore:indexes
```

Set payment webhook secret (optional until card payments go live):

```bash
firebase functions:secrets:set PAYMENT_WEBHOOK_SECRET
```

Webhook URL after deploy:

`https://asia-south1-mnd-masterndelivery.cloudfunctions.net/paymentWebhook`

Send header `x-mnd-signature: sha256=<hmac-sha256-hex>` of raw JSON body.

## Payment webhook body

```json
{
  "orderId": "abc123",
  "paymentStatus": "paid",
  "provider": "payhere",
  "transactionId": "TX-001"
}
```

`paymentStatus`: `paid` | `failed` | `refunded` | `pending`
