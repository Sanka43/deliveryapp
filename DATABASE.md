# MND — Database & Data Layer Overview

This document describes the **current** data storage used by the MND workspace (`mnd_customer` Flutter app, `mnd_web` static site) and **likely future** extensions. Primary online database: **Google Cloud Firestore** (Firebase project referenced from app config, e.g. `mnd-masterndelivery`).

---

## 1. Project layout (data-related)

| Area | Role |
|------|------|
| `mnd_customer/` | Main Flutter app: Firestore reads/writes, Firebase Auth, FCM |
| `mnd_customer/lib/core/constants/firebase_collections.dart` | Canonical collection name constants |
| `mnd_customer/firestore.rules` | Server-side access control |
| `mnd_customer/firestore.indexes.json` | Composite indexes for queries |
| `mnd_web/js/firebase-config.js` | Web Firebase client config (same project as mobile where applicable) |

**Not a server SQL database:** there is no Postgres/MySQL schema in-repo; operational truth for users, catalog, and orders is **Firestore documents**.

---

## 2. Other persistence (non-Firestore)

| Mechanism | Data | Notes |
|-----------|------|--------|
| **Firebase Authentication** | UID, phone/email providers, tokens | User identity; `customers/{uid}` doc mirrors profile fields |
| **SharedPreferences** | Notification UI toggles (`notif_pref_order_updates`, `notif_pref_promotions`) | Local only; FCM topics `mnd_order_updates`, `mnd_promotions` synced on device |
| **In-memory (Riverpod)** | Shopping cart, coupons, delivery notes, map drop-off coords | Not persisted to Firestore until checkout |
| **FCM** | Push delivery | Topics documented in `NotificationSettingsRepository`; no `device_tokens` writes found in current Flutter client |

---

## 3. Firestore collections (as implemented)

### 3.1 `customers` / `{uid}`

**Purpose:** Profile and role for signed-in customer/vendor/admin users; subcollection for saved addresses.

**Migration:** If you previously used the `users` collection, copy or move documents to `customers` with the same document id (Auth UID), then deploy updated rules and apps.

**Created/updated by app (`phone_auth_controller`, profile repo):**

| Field | Type | Notes |
|-------|------|--------|
| `uid` | string | Must match Auth UID; enforced on create |
| `role` | string | Default `'customer'` on customer sign-up. **Shop app** can self-register as **`vendor`** with `vendorStoreId == uid` (see `validVendorUserCreate` in rules); store doc `vendors/{uid}`. |
| `displayName` | string? | Merged with Auth display name in UI |
| `email` | string? | Optional; can be deleted on profile update |
| `phoneNumber` | string? | From phone auth or Google |
| `createdAt` | timestamp | Server on first create |
| `updatedAt` | timestamp | Server on updates |

**Optional (read by `CustomerProfile.merge` if present):**

| Field | Type |
|-------|------|
| `photoUrl` | string? |

**Job posting membership credits (admin-granted):**

| Field | Type | Notes |
|-------|------|--------|
| `jobPostCredits` | number | Remaining job posts the customer may submit (default `0` if missing). Each successful customer job create decrements by 1. |
| `jobPostCreditsUpdatedAt` | timestamp | Last credit change |
| `jobPostCreditsUpdatedBy` | string? | Admin UID when credits were granted |
| `jobsBlocked` | bool? | If `true`, customer cannot create jobs (enforced in rules + app) |

Admin grants credits from `mnd_web` Customers (amounts 1 / 5 / 10 / 20). Customers cannot self-increase credits; self-update may only decrement by 1 as part of job submit.

**Queries:** `user_role_provider` reads `role`; profile stream reads full doc; job post UI streams `jobPostCredits`.

**Rules:** Owner read/update (immutable `uid`/`role` on update; credit fields admin-grant or self decrement-only); admin read/update/delete; create only as customer with matching `uid` (no self-granted credits on create).

---

### 3.2 `customers` / `{uid}` / `saved_addresses` / `{addressId}`

**Purpose:** Customer delivery address book.

| Field | Type | Rules / validation |
|-------|------|---------------------|
| `label` | string | 1–48 chars |
| `line1` | string | 1–200 chars |
| `line2` | string | ≤200 chars |
| `city` | string | 1–80 chars |
| `phone` | string | 8–20 chars |
| `isDefault` | bool | Batch-updated when setting default |
| `createdAt` | timestamp | Set on add |

**Query:** `orderBy('createdAt', ascending: true)` — ensure index if scale grows (single-field may auto-index).

---

### 3.3 `vendors` / `{vendorId}`

**Purpose:** Stores (vendors) shown in customer home/search and used at order placement.

**Fields used by Flutter client:**

| Field | Type | Usage |
|-------|------|--------|
| `active` | bool | `== true` for listing; must be true in transaction to place order. Auto-synced from `openingHours` (Asia/Colombo) unless a manual override is active. |
| `openingHours` | map | Schedule from registration / profile: `defaultOpen` / `defaultClose` (`HH:MM`), `closedSunday` (bool), optional `note`. |
| `openOverrideUntil` | Timestamp? | When set and in the future, scheduler keeps current `active` until this instant (next open/close boundary after a manual toggle), then resumes auto hours. |
| `name` | string | Store name in search |
| `tag` | string? | **Shop type** label (e.g. Restaurant, Rice and curry) — shown on customer cards |
| `category` | string? | **Shop category** label (e.g. Food, Grocery) — broad bucket; not the same as `tag` |
| `rating` | number | Average of **visible** `store_ratings` (Cloud Function); shown on search cards |
| `ratingCount` | number | Count of visible ratings (Cloud Function) |
| `eta` | string | ETA label |
| `imageUrl` | string? | Hero / card image |
| `deliveryFee` | string or number | Display as fee string |
| `location` | GeoPoint? | Pickup coords for delivery fee / distance |
| `latitude` / `longitude` | number? | Alternative to `location` |
| `customFoodTypes` | string[]? | Shop-remembered food product types beyond presets (e.g. `Mutton`). Written by shop app when a product uses Type × Size options; shown as chips on later add-product forms. |

**Rules:** Any signed-in user read; write admin or vendor. Non-admin vendor updates cannot change `rating` / `ratingCount` (owned by Cloud Functions).

---

### 3.3.1 `shop_categories` / `{categoryId}`

**Purpose:** Broad groups for vendor registration and future customer filters (e.g. Food, Grocery).

| Field | Type | Notes |
|-------|------|--------|
| `label` | string | 1–80 chars |
| `order` | number | Sort ascending in admin + apps |
| `active` | bool | Hidden when false |

**Rules:** Public read; admin write (`mnd_customer/firestore.rules`).

---

### 3.3.2 `shop_types` / `{typeId}`

**Purpose:** Specific kinds under a **shop category** (e.g. Restaurant, Juice bar under Food).

| Field | Type | Notes |
|-------|------|--------|
| `label` | string | 1–80 chars |
| `categoryId` | string | Must reference a `shop_categories/{id}` document |
| `order` | number | Sort ascending within the category |
| `active` | bool | Hidden when false |

**Indexes:** Composite `categoryId` ASC + `order` ASC for vendor registration queries (`mnd_customer/firestore.indexes.json`).

**Rules:** Public read; admin write; creates/updates require valid `categoryId`.

**Migration (existing projects):** Older docs may lack `categoryId` until backfilled — rules require the field on new writes. After deploy:

1. In Firestore, create at least one `shop_categories` document (e.g. label `Food`, `order: 0`, `active: true`) and note its **document id**.
2. For each `shop_types` document, set `categoryId` to that id (or split by label as needed).
3. Re-save or delete unusable rows; then use **MND Admin → Shop types** to add new types.

---

### 3.3.3 `grocery_aisles` / `{aisleId}`

**Purpose:** Product aisle labels for grocery shops (e.g. Dairy, Snacks). Used by the shop add-product form and customer grocery hub chips. Distinct from `shop_types` (those are shop kinds like Mini mart).

| Field | Type | Notes |
|-------|------|--------|
| `label` | string | 1–80 chars; stored on products as `productCategory` when vendor picks an aisle |
| `order` | number | Sort ascending in admin + apps |
| `active` | bool | Hidden when false |

**Rules:** Public read; admin write (`mnd_customer/firestore.rules`).

**Admin:** MND Admin → Shop types view → **Grocery aisles** panel (add / edit / active / delete; seed defaults when empty).

**Defaults (seed):** Fresh Produce, Dairy, Bakery, Beverages, Snacks, Household, Personal Care, Other.

---

### 3.4 `products` / `{productId}`

**Purpose:** Catalog items; global collection filtered by `storeId` / `active`.

**Fields referenced in code:**

| Field | Type | Usage |
|-------|------|--------|
| `active` | bool | Search stream `where('active', isEqualTo: true)` |
| `storeId` | string | Link to vendor; availability stream per store |
| `name` | string | Display / search |
| `price` | number or string | LKR display / parsing |
| `imageUrl` | string? | |
| `lookupKey` | string? | Stable key for cart + availability map; fallback `productId` or doc id or slug from `name` |
| `productId` | string? | Alternate lookup |
| `storeName` | string? | Fallback `vendorName` |
| `vendorName` | string? | Fallback store label |
| `description` | string? | Shop product details |
| `stockQty` | number? | On-hand units when `manageStock` is true |
| `manageStock` | bool? | When `true`, customer treats `stockQty ≤ 0` as unavailable; missing/`false` = stock not tracked (always available if active) |
| `eta` | string? | Product-level ready / prep time label |
| `sizeOptions` | array? | `{ name, priceLkr }` absolute LKR variants (food sizes, grocery packs, or Type × Size combos) |
| `productCategory` | string? | Grocery aisle label (e.g. Dairy, Snacks); used by customer grocery chips when set |
| `isAvailable` | bool? | Availability precedence |
| `inStock` | bool? | Second precedence |
| `active` | bool? | Third precedence for availability |

**Type × Size combos (food):** Shop form can optionally add a second dimension (Chicken / Beef / Egg / custom types) on top of Size, Portion, or Half/Full. Each sold combo is stored as one `sizeOptions` row with name `{Type} · {Size}` (middle dot), e.g. `Chicken · Full`, `Beef · Half`, each with its own absolute `priceLkr`. Customer product sheet detects this pattern and shows **Choose type** then **Choose size**; cart/order still send a single `selectedSize` equal to the full combo label. Grocery pack pricing is unchanged (no type dimension).

**Grocery vs food (shop app):** Vendors with `category`/`tag` matching grocery heuristics get aisle + pack presets in the product form; food shops keep size/portion/half (plus optional type matrix). Grocery add-product includes optional **Manage stock**; customer availability only enforces `stockQty` when `manageStock` is true. Customer grocery hub chips and shop aisle dropdown read `grocery_aisles` (fallback to hardcoded labels when empty). Prefers `productCategory` over name keywords when present.

**Note:** Store detail tabs still use **local demo product lists**; Firestore is used for **availability overlay** (`storeProductAvailabilityProvider`) and global search — full Firestore-driven product grids may come later.

**Rules:** Any signed-in user read; write admin or vendor.

---

### 3.5 `banners` / `{bannerId}`

**Purpose:** Marketing strips on customer home.

| Field | Type |
|-------|------|
| `active` | bool |
| `title` | string |
| `subtitle` | string |
| `startColor` | int (ARGB) or hex `string` |
| `endColor` | int or hex `string` |
| `iconKey` | string |
| `order` | number | Sort ascending in app |

**Rules:** Signed-in read; admin write.

---

### 3.5b `offers` / `{offerId}`

**Purpose:** Standalone shop offers (not product discounts). Vendor creates → admin approves → customer home banner + store page. Expired offers stay for sale history.

| Field | Type | Notes |
|-------|------|--------|
| `storeId`, `storeName` | string | Vendor owner (`storeId` usually Auth UID) |
| `title` | string | Offer name |
| `description` | string? | Optional |
| `imageUrl` | string | Promo image (`vendor_offers/{storeId}/…`) |
| `priceLkr` | int | Sell price |
| `endsAt` | timestamp | Required end time |
| `status` | string | `pending` \| `approved` \| `rejected` |
| `rejectionReason` | string? | Admin note |
| `approvedAt` | timestamp? | |
| `approvedBy` | string? | Admin uid |
| `order` | number | Banner sort |
| `createdBy` | string | Vendor uid |
| `createdAt`, `updatedAt` | timestamp | |

**Live for customers:** `status == approved` AND `endsAt > now` (client filter). Docs are not deleted on expiry.

**Rules:** Approved readable by anyone; vendor reads own store; vendor create forces `pending`; vendor update cannot set `approved`; admin full write.

---

### 3.6 `riders` / `{riderId}`

**Purpose:** Operational rider profile + **live location** for tracking UI.

**Location fields (read by `RiderLiveLocation.fromMap`):**

| Field | Type |
|-------|------|
| `currentLocation` or `location` | GeoPoint |
| or `latitude` / `longitude` | number |
| `heading` | number? (degrees) |
| `locationUpdatedAt` or `updatedAt` | timestamp |

**App expectation:** Order detail may reference `riderId` or `assignedRiderId` (both read paths exist).

**Rating fields (read by `mnd_rider` profile):**

| Field | Type | Notes |
|-------|------|--------|
| `rating` | number | Average of **visible** `rider_ratings` (Cloud Function); shown on rider profile |
| `ratingCount` | number | Count of visible ratings (Cloud Function) |

**Preference fields:**

| Field | Type | Notes |
|-------|------|--------|
| `acceptsPassengerRides` | bool | Rider self-toggle in Settings. Missing/absent treated as `true` (opt-out, not opt-in). Gates only *new* ride offers — an already-accepted trip stays visible/completable regardless. |

**Compliance document fields:**

| Field | Type | Notes |
|-------|------|--------|
| `licensePhotoUrl` / `licenseExpiresAt` | string / timestamp (date-only) | Driving license |
| `insurancePhotoUrl` / `insuranceExpiresAt` | string / timestamp (date-only) | Insurance |
| `revenueLicensePhotoUrl` / `revenueLicenseExpiresAt` | string / timestamp (date-only) | Revenue license |
| `licenseReminderDaysSent` / `insuranceReminderDaysSent` / `revenueLicenseReminderDaysSent` | number\|null | Last reminder bucket (14/7/1) sent per doc — Cloud Function only |
| `complianceExpiredFields` | array of `'license'`\|`'insurance'`\|`'revenueLicense'` | Set by the expiry sweep when it flips `status` to `pending`; server-only |

Rider self-write of `licensePhotoUrl`/`licenseExpiresAt`/`insurancePhotoUrl`/`insuranceExpiresAt`/`revenueLicensePhotoUrl`/`revenueLicenseExpiresAt`/`vehicleType`/`vehicleNumber` (via `riderComplianceKeys()`) forces `status → 'pending'` in the same write, re-flagging the rider for admin review.

**Document expiry sweep (Cloud Function `sweepRiderDocumentExpiry`, daily 8am Colombo):** Scans `riders` where `status in ['approved','active']`.

| `daysUntilExpiry` (Colombo calendar day) | Action |
|---|---|
| 14, 7, or 1 (bucketed; self-healing if a run is missed) | Push + inbox notification `documents_expiring`, marker field updated so the same bucket isn't resent |
| `< 0` (expired) | `status → 'pending'`, `online → false`, `complianceExpiredFields` set, push + inbox notification `documents_expired` — stops an already-online rider from continuing to take jobs on an expired document |

**Rules:** Any signed-in read; rider can create/update own `riders/{uid}` doc (self-update field allow-lists exclude `rating`/`ratingCount`/reminder markers/`complianceExpiredFields`/all `cash*` fields — Cloud Functions only); admin full control.

---

**Cash-in-hand fields (server-only — every rider self-update path is a `hasOnly()` allow-list that excludes them):**

| Field | Type | Notes |
|-------|------|--------|
| `cashInHandLkr` | int | Collected cash the rider has not handed over: cash ride fares + COD `amountDueFromCustomer` |
| `cashOwedToAdminLkr` | int | The slice of the above that must reach admin: shop product cash + service charge + ride commission |
| `cashPendingSettlementLkr` | int | Locked in a handover waiting for admin confirmation |
| `cashHoldActive` | bool | `true` once `cashInHandLkr` goes **above** `platform_config/fees.maxRiderCashInHandLkr` |
| `cashHoldSince` | timestamp\|null | Stamped when the hold starts, cleared when it lifts |
| `cashUpdatedAt` | timestamp | Last cash-counter write |

While `cashHoldActive` is true, `riderCashHoldActive()` in `firestore.rules` rejects `validRiderClaimTrip()` and `validRiderClaimOrder()` — the rider can claim no new ride or delivery. It is deliberately **not** applied to the progress rules, so work already in flight stays finishable.

#### 3.6.1 `riders` / `{riderId}` / `cash_ledger` / `{entryId}`

One row per cash job. Written only by `onTripCompletedCreditRider` / `onOrderDeliveredCreditRider` and the settlement callables (Admin SDK). Deterministic ids — `ride_{tripId}`, `order_{orderId}` — make the writes idempotent.

| Field | Type | Notes |
|-------|------|--------|
| `type` | `'ride_cash'` \| `'order_cash'` | |
| `cashLkr` | int | Cash the rider took from the customer |
| `owedLkr` | int | Of that, what must reach admin (ride commission, or the order's `productCashLkr` + `serviceCharge`) |
| `breakdown` | map | `{productCashLkr, serviceChargeLkr, rideCommissionLkr}` — component split of `owedLkr`; absent on entries written before this field existed, in which case `owedLkr` is inferred as 100% `productCashLkr` (order) or 100% `rideCommissionLkr` (ride) |
| `status` | `'open'` → `'pending_settlement'` → `'settled'` | Reject sends it back to `'open'` |
| `settlementId` | string? | Set while pending/settled |
| `tripId` / `orderId` | string? | Whichever applies |
| `title` / `subtitle` | string | Rider-facing labels |
| `createdAt` / `settledAt` | timestamp | |

#### 3.6.2 `riders` / `{riderId}` / `cash_settlements` / `{settlementId}`

A handover the rider asked admin to confirm (`riderRequestCashSettlement`), closed by `adminConfirmCashSettlement` / `adminRejectCashSettlement`. Confirming also advances the covered orders' `productCashStatus` to `remitted_to_admin`, which is why the per-order `riderMarkProductCashRemitted` path is deprecated.

| Field | Type | Notes |
|-------|------|--------|
| `riderId` | string | |
| `amountLkr` | int | Total owed to admin in this handover |
| `cashCoveredLkr` | int | Total collected cash the handover clears |
| `breakdown` | map | `{productCashLkr, serviceChargeLkr, rideCommissionLkr}` |
| `entryIds` / `orderIds` / `tripIds` | array\<string\> | Snapshot at request time, capped at 200 entries |
| `entryCount` | int | |
| `status` | `'requested'` \| `'confirmed'` \| `'rejected'` | |
| `method` | `'bank'` \| `'cash'` | |
| `reference` | string? | Deposit slip reference / note |
| `requestedAt/By`, `confirmedAt/By`, `rejectedAt/By`, `rejectReason` | | Audit trail |

**Rules:** both subcollections are read-only to the owning rider and admin; all writes go through Cloud Functions. A collection-group read on `cash_settlements` is allowed for admin (the mnd_web handover queue), mirroring `withdrawals`.

---

### 3.7 `orders` / `{orderId}`

**Purpose:** Customer orders; COD placement from app or vendor phone/manual create; lifecycle + cancellation fields.

**On create (customer COD, via `placeCashOnDeliveryOrder`):**

| Field | Type |
|-------|------|
| `customerId` | string (Auth UID) |
| `vendorId` | string — **store id**; same value as `vendors/{id}` document id (see below). |
| `vendorStoreId` | string (optional duplicate) — app writes **same value as `vendorId`** so order docs align with the `vendorStoreId` field name used on `vendors` / profile docs. Rules accept either field when resolving store access. |
| `storeName` | string |
| `status` | `'placed'` |
| `paymentMethod` | `'cashOnDelivery'` |
| `items` | list of maps (see below) |
| `subtotal`, `discount`, `deliveryFee`, `total` | int (LKR) |
| `deliveryAddress` | map: `line1`, `line2`, `city`, `phone` |
| `deliveryNote`, `specialInstructions` | string |
| `createdAt` | timestamp |
| `dropoffLatitude`, `dropoffLongitude` | number? |
| `couponCode` | string? |
| `serverPlaced` | bool — `true` when created by Cloud Function |
| `fulfillmentMode` | `'delivery'` \| `'selfPickup'` |

**On create (vendor phone / manual, via `placeVendorManualOrder`):**

Same pricing fields as customer COD, plus:

| Field | Type | Notes |
|-------|------|--------|
| `status` | `'confirmed'` | Vendor already took the order (skips Accept) |
| `orderSource` | `'vendor_manual'` | Distinguishes from customer-app orders |
| `createdByVendorUid` | string | Auth UID of the shop user who created it |
| `customerName` | string | Required for guests; filled from profile when linked |
| `customerPhoneE164` | string | Normalized phone |
| `isGuestCustomer` | bool | `true` when no Auth user for that phone |
| `customerId` | string | Auth UID when linked, else `guest_<nationalDigits>` |
| `fulfillmentMode` | `'delivery'` | v1 delivery-only; Mark ready opens rider pool |
| `productsPaid` | bool | Customer already paid shop for products; rider collects delivery only when true |
| `deliveryFeeMode` | `'actual_trip'` | Fee finalized from rider path KM via `completeDeliveryOrder` |
| `deliveryFee` | int | `0` until deliver; then fee from traveled km |
| `total` | int | `productsPaid ? 0 : subtotal` until deliver; then subtotal−discount+deliveryFee |
| `dropoffLatitude`, `dropoffLongitude` | number? | Optional map pin |
| `traveledKm` | number? | Set on complete (1 decimal) |
| `amountDueFromCustomer` | int? | Set on complete: delivery only if `productsPaid`, else products+delivery |
| `productCashLkr` | int | Product cash rider holds when not paid (`subtotal − discount`); `0` if paid |
| `productCashStatus` | `'none'` \| `'owed'` \| `'remittance_requested'` \| `'remitted_to_admin'` \| `'settled_to_shop'` | Admin settlement ledger. `owed → remitted_to_admin` now normally happens via `adminConfirmCashSettlement` (see 3.6.2); the per-order `remittance_requested` step is the deprecated `riderMarkProductCashRemitted` path. |
| `productCashRiderId` | string? | Rider who owes product cash |
| `productCashRemittedAt` / `productCashSettledAt` | timestamp? | Admin transition times |
| `productCashRemittedBy` / `productCashSettledBy` | string? | Admin UID |

Lookup helper: callable `lookupVendorOrderCustomer` (vendor auth) returns found/guest + optional saved address hints.

Completion helper: callable `completeDeliveryOrder` (assigned rider) takes `orderId` + `traveledKm`, writes fee/total/`amountDueFromCustomer` / product-cash ledger, sets `status: delivered`.

Product cash admin helpers: `adminMarkProductCashRemitted` (`owed` → `remitted_to_admin`), `adminMarkProductCashSettledToShop` (`remitted_to_admin` → `settled_to_shop`).

**Order line item map (`_cartItemToMap`):**

| Field | Type |
|-------|------|
| `productKey`, `productName`, `storeId`, `storeName`, `imageUrl`, `selectedSize` | string |
| `quantity` | int |
| `basePrice`, `sizePriceDelta`, `unitPrice`, `lineTotal` | int |
| `extras` | list of `{ name, priceDelta }` |

**Customer cancellation updates (`CustomerOrdersRepository`):**

| Field | Type |
|-------|------|
| `status` | `'cancelled'` |
| `cancellationReason` | string (preset id, e.g. `changed_mind`) |
| `cancellationReasonDetail` | string? (when reason is `other`) |
| `cancelledAt` | timestamp |
| `cancelledBy` | `'customer'` |

**Vendor accept reminders (Cloud Function `sweepStalePlacedOrders`, every 1 min):** Customer `placed` orders (not `vendor_manual`) that the shop has not confirmed.

| Elapsed | Action |
|---------|--------|
| +2 min | Vendor inbox + FCM `order_reminder` (stage 1) |
| +5 min | Final vendor reminder (stage 2) |
| +7 min | Auto-cancel + admin escalate |

| Field | Type |
|-------|------|
| `vendorAcceptReminderStage` | int — `0` / missing, `1`, or `2` |
| `status` | `'cancelled'` on timeout |
| `cancelledBy` | `'system'` |
| `cancellationReason` | `'vendor_no_response'` |
| `cancelledAt` | timestamp |
| `adminEscalated` | bool |
| `adminEscalatedAt` | timestamp |
| `adminEscalationReason` | `'vendor_no_response'` |

**Other fields (read by detail UI, may be set by ops/admin):**

| Field | Type |
|-------|------|
| `riderId` or `assignedRiderId` | string? |
| `openForRiders` | bool — `true` when vendor marks `ready`; `false` on rider accept/cancel |
| `riderAcceptedAt` | timestamp — set when rider claims job (`mnd_rider`) |
| `pickupLatitude`, `pickupLongitude` | number? — optional snapshot from vendor at claim |
| `storeRated` | bool — `true` after customer submits a shop rating |
| `storeRatingStars` | int? — 1–5 stars denormalized for order UI |
| `riderRated` | bool — `true` after customer submits a rider rating |
| `riderRatingStars` | int? — 1–5 stars denormalized for order UI |

**Rider self-accept (`mnd_rider`):** Query `openForRiders == true` && `status == 'ready'`. Claim transaction sets `assignedRiderId`, `riderId`, `openForRiders: false`, `status: 'out_for_delivery'`, `riderAcceptedAt`.

**Status values referenced in UI/policy:** `placed`, `confirmed`, `preparing`, `ready`, `out_for_delivery`, `on_the_way`, `delivered`, `cancelled` (not all enforced in rules — align with backend).

**Queries:** `where('customerId', isEqualTo: uid).orderBy('createdAt', descending: true)` — composite index defined.

**Rules:** Customer read/update own; admin/rider/vendor broader read/update (see `firestore.rules`). Create validated with `validOrderCreate` / admin variant.

---

### 3.7.1 `store_ratings` / `{orderId}`

**Purpose:** Customer → shop ratings after delivery. Document id equals the order id (one rating per order).

| Field | Type | Notes |
|-------|------|--------|
| `orderId` | string | Same as document id |
| `customerId` | string | Auth UID of rater |
| `vendorId` | string | Shop id |
| `storeName` | string | Denormalized for admin list |
| `stars` | int | 1–5 |
| `comment` | string | Optional, ≤500 chars |
| `status` | string | `visible` \| `hidden` (admin moderation) |
| `createdAt` / `updatedAt` | timestamp | |

**Create (customer):** Order must be `delivered`, owned by the customer, and not already rated (`storeRated != true`). Same transaction sets `orders.storeRated` / `storeRatingStars`.

**Aggregation:** Cloud Functions `onStoreRatingCreated` / `Updated` / `Deleted` recompute `vendors.rating` (1 decimal) and `vendors.ratingCount` from visible ratings.

**Admin:** `mnd_web` Rating Management — hide/unhide (`status`) or delete.

**Rules:** Customer create with validation; signed-in read of visible (or own); admin update status / delete.

---

### 3.7.2 `rider_ratings` / `{orderId}`

**Purpose:** Customer → rider ratings after delivery. Document id equals the order id (one rating per order). Delivery orders only (not `trips`).

| Field | Type | Notes |
|-------|------|--------|
| `orderId` | string | Same as document id |
| `customerId` | string | Auth UID of rater |
| `riderId` | string | Assigned rider's Auth UID (from order's `riderId`/`assignedRiderId`) |
| `stars` | int | 1–5 |
| `comment` | string | Optional, ≤500 chars |
| `status` | string | `visible` \| `hidden` (admin moderation) |
| `createdAt` / `updatedAt` | timestamp | |

**Create (customer):** Order must be `delivered`/`completed`, owned by the customer, have a rider assigned, and not already rated (`riderRated != true`). Same transaction sets `orders.riderRated` / `riderRatingStars`.

**Aggregation:** Cloud Functions `onRiderRatingCreated` / `Updated` / `Deleted` recompute `riders.rating` (1 decimal) and `riders.ratingCount` from visible ratings.

**Rules:** Customer create with validation; signed-in read of visible (or own); admin update status / delete.

---

### 3.8 `notifications` / `{notificationId}`

**Purpose:** Per-user notification feed (rules assume `userId` on document).

**Rules:** User read only if `resource.data.userId == request.auth.uid`; admin manages writes.

**Client:** No Flutter repository usage found in current tree — **reserved for future or server-driven feed**.

---

### 3.8.1 `admin_alerts` / `{orderId}`

**Purpose:** Durable ops record when a shop does not confirm a `placed` order in time. Written by `sweepStalePlacedOrders` (Admin SDK). Document id equals the order id.

| Field | Type |
|-------|------|
| `type` | `'vendor_no_response'` |
| `orderId` | string |
| `vendorId` | string |
| `storeName` | string |
| `trackingNumber` | string |
| `customerId` | string |
| `createdAt` | timestamp |
| `read` | bool |

**Rules:** Admin read/update/delete; create is Cloud Functions only.

---

### 3.9 `device_tokens` / `{tokenId}`

**Purpose:** FCM device registration keyed for targeted push.

**Rules:** Owner read/write with `userId` matching Auth.

**Client:** No writes located in current Flutter code — **future**: register token here or rely purely on topics.

---

### 3.10 `admins` (constant only)

`FirebaseCollections` defines `admins` for possible future use — **not referenced** by the scanned Dart sources in-repo.

---

## 4. Firestore composite indexes (`firestore.indexes.json`)

| Collection | Fields | Likely query |
|------------|--------|--------------|
| `banners` | `active` ASC, `order` ASC | Active banners sorted |
| `vendors` | `active` ASC, `name` ASC | Optional / future sort |
| `products` | `active` ASC, `name` ASC | Optional / future sort |
| `orders` | `customerId` ASC, `createdAt` DESC | My orders |
| `orders` | `status` ASC, `createdAt` DESC | Ops dashboards; `sweepStalePlacedOrders` (placed + createdAt) |
| `orders` | `vendorId` ASC, `createdAt` DESC | Vendor shop app order board (`mnd_shop`) |
| `orders` | `assignedRiderId` ASC, `createdAt` DESC | Rider assigned jobs (`mnd_rider`) |
| `orders` | `openForRiders` ASC, `status` ASC, `createdAt` DESC | Open jobs pool (`mnd_rider`) |
| `orders` | `riderId` ASC, `status` ASC, `createdAt` DESC | Rider earnings/history (`mnd_rider`) |
| `store_ratings` | `vendorId` ASC, `createdAt` DESC | Ratings by shop |
| `store_ratings` | `status` ASC, `createdAt` DESC | Admin filter |
| `store_ratings` | `vendorId` ASC, `status` ASC | CF aggregation query |
| `rider_ratings` | `riderId` ASC, `createdAt` DESC | Ratings by rider |
| `rider_ratings` | `status` ASC, `createdAt` DESC | Admin filter |
| `rider_ratings` | `riderId` ASC, `status` ASC | CF aggregation query |
| `cash_ledger` | `status` ASC, `createdAt` ASC | Rider's outstanding cash + settlement snapshot |
| `cash_settlements` (collection group) | `status` ASC, `requestedAt` DESC | Admin handover queue (mnd_web) |

**Vendor onboarding (required for `mnd_shop` order reads/updates):** In Firestore `customers/{vendorAuthUid}`, set `role` to `vendor` and add string field `vendorStoreId` equal to the same id used in `vendors/{id}` and in customer orders as `vendorId`. The shop app can write this field via **Sync store ID to profile** after you set the store id under Products.

---

## 5. Security model (summary)

- **Role** is resolved from `customers/{request.auth.uid}` for admin/customer/vendor checks; rider privileges are based on existence of `riders/{request.auth.uid}`.
- **Customers** can create orders only with strict field checks (COD, own `customerId`, etc.).
- **Vendor order access:** Vendors may read/update `orders` only when `customers/{uid}.vendorStoreId` is set and equals the order’s `vendorId` (see `vendorMayAccessThisOrder` in `firestore.rules`).
- **Rider location:** Riders may create/update their own document `riders/{request.auth.uid}` for live tracking (GPS / online flags); admin retains full control.
- **Vendors / products / banners / offers / riders** writes are privileged (admin ± vendor where noted).
- **Saved addresses** have field-size validation in rules.
- **Gap to watch:** `orders` `allow update` for customers is broad in rules text — app only sends cancellation fields; **tighten rules** to allowed field paths for customer role when hardening.

---

## 5.1 Jobs module collections (`mnd_customer`)

| Collection | Purpose |
|------------|---------|
| `jobs` | Employment listings (`status`: `pending`, `active`, `rejected`, `expired`) |
| `job_applications` | Quick apply submissions (`applicantId`, `jobId`, `cvUrl`, …) |
| `saved_jobs` | User bookmarks (`userId`, `jobId`, `savedAt`) |
| `job_reports` | Safety reports (`reporterId`, `jobId`, `reason`) |

Public browse: active `jobs` only. New posts require admin approval (`pending` → `active`).

Customer job create also requires `customers/{uid}.jobPostCredits > 0` and `jobsBlocked != true`. Submit decrements one credit in the same Firestore transaction. Admin-created jobs skip the credit check.

---

## 5.2 Passenger rides (`trips` / `ride_fare_quotes` / `ride_fare_config`)

### `platform_config` / `fees`

Admin-editable knobs from the **Fees & commissions** page in `mnd_web`. Read server-side by `loadPlatformFeeConfig()` (functions/src/platformConfig.ts); every field falls back to a code default when missing, out of range, or unreadable, so checkout never breaks on a config problem. Signed-in read, admin write.

| Field | Type | Default | Used by |
|-------|------|---------|---------|
| `serviceChargePercent` | number 0–100 | 5 | Order service charge at checkout |
| `minDeliveryFeeLkr` | int | 120 | Delivery-fee curve (first 2.5 km) |
| `pricePerKmLkr` | int | 42 | Delivery-fee curve (after 2.5 km) |
| `shopMonthlyCommissionPercent` | number 0–100 | 1 | Monthly shop invoices (admin-generated) |
| `rideCommissionLkr` | int | 0 | Flat platform cut per completed passenger ride |
| `maxRiderCashInHandLkr` | int | 7000 | Cash a rider may hold before new jobs stop being claimable |

`riderCommissionLkr` and `orderCommissionLkr` are legacy fields that were never read by anything; the fees page deletes both on save.

### `ride_fare_config` / `rates`

Admin-managed pricing for passenger rides. Cloud Function `quoteRideFares` reads this doc (falls back to built-in defaults if missing). Signed-in customers may read for UI previews; only admins write.

| Field | Type |
|-------|------|
| `bike` / `wheel` / `car` | `{ baseLkr: int, perKmLkr: int, minLkr: int, perStopLkr: int }` |
| `updatedAt` | timestamp? |
| `updatedBy` | string? (admin uid) |

**Formula:** `fareLkr = max(minLkr, baseLkr + ceil(distanceKm × perKmLkr) + stopCount × perStopLkr)`, where `distanceKm` sums the haversine legs `pickup → stop₁ → stop₂ → dropoff`. `perStopLkr` defaults to `0` for configs written before this field existed.

### `ride_fare_quotes` / `{quoteId}`

Written only by Cloud Function `quoteRideFare` / `quoteRideFares` (Admin SDK). Customer may read own quote.

| Field | Type |
|-------|------|
| `customerId` | string |
| `vehicleType` | `'wheel'` \| `'bike'` \| `'car'` |
| `pickup` / `dropoff` | `{ lat, lng, label }` |
| `stops` | `{ lat, lng, label }[]` — 0-2 intermediate stops, in visit order |
| `distanceKm` | number |
| `fareLkr` | int |
| `expiresAt` | timestamp |
| `createdAt` | timestamp |

### `trips` / `{tripId}`

| Field | Type |
|-------|------|
| `customerId` | string |
| `contactPhone` | string |
| `driverNote` | string? |
| `pickup` / `dropoff` | `{ lat, lng, label }` |
| `stops` | `{ lat, lng, label }[]` — 0-2 intermediate stops, in visit order (copied from the fare quote; absent on trips created before this field existed) |
| `currentStopIndex` | int — how many stops the assigned rider has visited so far; only advances while `status == 'in_progress'`, via a dedicated Firestore-rules-guarded update (not a `status` transition) |
| `vehicleType` | `'wheel'` \| `'bike'` \| `'car'` |
| `distanceKm` | number |
| `estimatedFareLkr` | int |
| `fareQuoteId` | string |
| `status` | `draft_payment` → `searching` → `accepted` → `arrived` → `in_progress` → `completed` \| `cancelled` |
| `openForRiders` | bool |
| `riderId` / `assignedRiderId` | string? |
| `riderAcceptedAt` | timestamp? |
| `paymentMethod` | `'cash'` \| `'payhere'` |
| `paymentStatus` | `'pending'` \| `'paid'` \| `'failed'` \| `'refunded'` |
| `paymentProvider` / `paymentTransactionId` | string? |
| `paidAt` / `createdAt` / `updatedAt` / `cancelledAt` | timestamp |

**Rider claim (`mnd_rider`):** `openForRiders == true` && `status == 'searching'`. Sets `accepted`, clears pool flag.

**PayHere:** `createPayHereCheckout` creates `draft_payment`; `payHereNotify` / `paymentWebhook` with `tripId` sets `paid` then `searching` + `openForRiders: true`. For rides paid online, payment is actually collected after the trip ends — see `needsOnlinePayment` in the customer app (`status == 'completed' && paymentMethod == 'payhere' && paymentStatus != 'paid'`) and `createPayHereCheckoutForTrip` / `markTripPaidAfterCompletion`.

**Stops (`mnd_rider` navigation):** with intermediate stops, the rider app tracks the active leg as `pickup → stop₁ → stop₂ → dropoff` using `currentStopIndex`, independent of `status`. Only the final leg (`currentStopIndex == stops.length`, heading to drop-off) transitions `status` to `completed`.

**Payment confirmation is decoupled from completion for both payment methods** — `completeCashOrRideTrip` only ever sets `status: 'completed'` + `completedAt`; it does not touch `paymentStatus`. Each method settles `paymentStatus` separately, after completion, via its own callable:

| Method | Who confirms | Callable |
|---|---|---|
| `cash` | Rider (explicit "Payment received" tap in `mnd_rider`, after seeing the ride summary) | `confirmCashRidePayment` — rider-only, requires `status == 'completed' && paymentMethod == 'cash'`, sets `paymentStatus: 'paid'`, `paymentProvider: 'cash'`, `paidAt`. Idempotent. |
| `payhere` | Customer (pays online after the ride, from the "Pay now" prompt) | `createPayHereCheckoutForTrip` / `markTripPaidAfterCompletion` (existing, unchanged) |

**Rider earnings and commission (`onTripCompletedCreditRider`, fires on `completed` + `paid`):** the rider earns `estimatedFareLkr − platform_config/fees.rideCommissionLkr` (commission is capped at the fare). Where that money sits depends on who collected it:

| Payment method | `riders/{id}/wallet/summary.balanceLkr` | `riders/{id}/cash_ledger` |
|---|---|---|
| `payhere` | credited with fare − commission | untouched — the platform holds the cash |
| `cash` | **not credited** — the rider was paid in full at the kerb | `ride_{tripId}` entry: `cashLkr` = fare, `owedLkr` = commission |

`earnings_aggregates` is incremented by fare − commission either way, so the rider's earnings charts show what they actually earned. The same rule applies to deliveries in `onOrderDeliveredCreditRider`: a COD order records an `order_{orderId}` cash entry (`cashLkr` = `amountDueFromCustomer` or `total`, `owedLkr` = `productCashLkr` + `serviceCharge`) and skips the wallet credit, while an online-paid order credits `deliveryFee` as before. The invariant is that `wallet.balanceLkr` only ever holds money the **platform** owes the rider.

The rider app shows a ride-summary sheet on completion (fare, distance, route) instead of exiting immediately; for cash trips it stays until the rider confirms, or they can tap "Done" without confirming. The customer's live-tracking screen reflects the unconfirmed state as "Waiting for the driver to confirm cash payment" rather than assuming payment collected.

---

## 6. Future database evolution (recommended)

1. **`device_tokens` + Cloud Functions** — Persist FCM tokens per user doc for transactional notifications; keep topics for broadcasts.
2. **`notifications` subcollection** — `customers/{uid}/notifications` vs top-level; align with query patterns and retention.
3. **Payment expansion** — Food checkout still COD-only; rides support cash + PayHere via `trips`.
4. **Coupon integrity** — Server-side validation (Cloud Function or backend) before trusting `discount` / `couponCode` on orders.
5. **Multi-vendor carts** — Today cart assumes single `storeId`; schema already per-line `storeId` but placement uses first item only — future split orders or merged delivery fee model.
6. **Product schema** — Formalize `sizes[]`, `extras[]` in Firestore to match cart line shape; retire demo tabs or load tabs from `category` / flags.
7. **`admins` collection** — If introduced for audit logs, document denormalization vs `customers` to avoid drift.
8. **Analytics / reporting** — BigQuery export or aggregate collections for vendor dashboards (avoid heavy client queries).
9. **Indexes** — Add composite indexes when adding `where` + `orderBy` on new fields (e.g. `vendorId` + `createdAt` for store order boards).
10. **Geospatial** — If querying “vendors near me” at scale, evaluate GeoFirestore or precomputed zones in addition to storing `GeoPoint`.
11. **Ride Directions API** — Replace haversine + straight polyline with Google Routes when ready.
## 7. How to keep this document accurate

After schema or rules changes, update:

- `firebase_collections.dart` (names)
- `firestore.rules` (authoritative validation)
- This file **field tables** and **section 6** roadmap items

---

*Generated from repository analysis; Firestore is schemaless — unknown fields may exist in production documents that the app ignores.*
