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

**Queries:** `user_role_provider` reads `role`; profile stream reads full doc.

**Rules:** Owner read/update (immutable `uid`/`role` on update); admin read; create only as customer with matching `uid`.

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
| `active` | bool | `== true` for listing; must be true in transaction to place order |
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
| `isAvailable` | bool? | Availability precedence |
| `inStock` | bool? | Second precedence |
| `active` | bool? | Third precedence for availability |

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

**Rules:** Any signed-in read; rider can create/update own `riders/{uid}` doc; admin full control.

---

### 3.7 `orders` / `{orderId}`

**Purpose:** Customer orders; COD placement from app; lifecycle + cancellation fields.

**On create (customer COD, from `OrderPlacementRepository`):**

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

**Other fields (read by detail UI, may be set by ops/admin):**

| Field | Type |
|-------|------|
| `riderId` or `assignedRiderId` | string? |
| `openForRiders` | bool — `true` when vendor marks `ready`; `false` on rider accept/cancel |
| `riderAcceptedAt` | timestamp — set when rider claims job (`mnd_rider`) |
| `pickupLatitude`, `pickupLongitude` | number? — optional snapshot from vendor at claim |
| `storeRated` | bool — `true` after customer submits a shop rating |
| `storeRatingStars` | int? — 1–5 stars denormalized for order UI |

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

### 3.8 `notifications` / `{notificationId}`

**Purpose:** Per-user notification feed (rules assume `userId` on document).

**Rules:** User read only if `resource.data.userId == request.auth.uid`; admin manages writes.

**Client:** No Flutter repository usage found in current tree — **reserved for future or server-driven feed**.

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
| `orders` | `status` ASC, `createdAt` DESC | Ops dashboards (future/vendor/rider consoles) |
| `orders` | `vendorId` ASC, `createdAt` DESC | Vendor shop app order board (`mnd_shop`) |
| `orders` | `assignedRiderId` ASC, `createdAt` DESC | Rider assigned jobs (`mnd_rider`) |
| `orders` | `openForRiders` ASC, `status` ASC, `createdAt` DESC | Open jobs pool (`mnd_rider`) |
| `orders` | `riderId` ASC, `status` ASC, `createdAt` DESC | Rider earnings/history (`mnd_rider`) |
| `store_ratings` | `vendorId` ASC, `createdAt` DESC | Ratings by shop |
| `store_ratings` | `status` ASC, `createdAt` DESC | Admin filter |
| `store_ratings` | `vendorId` ASC, `status` ASC | CF aggregation query |

**Vendor onboarding (required for `mnd_shop` order reads/updates):** In Firestore `customers/{vendorAuthUid}`, set `role` to `vendor` and add string field `vendorStoreId` equal to the same id used in `vendors/{id}` and in customer orders as `vendorId`. The shop app can write this field via **Sync store ID to profile** after you set the store id under Products.

---

## 5. Security model (summary)

- **Role** is resolved from `customers/{request.auth.uid}` for admin/customer/vendor checks; rider privileges are based on existence of `riders/{request.auth.uid}`.
- **Customers** can create orders only with strict field checks (COD, own `customerId`, etc.).
- **Vendor order access:** Vendors may read/update `orders` only when `customers/{uid}.vendorStoreId` is set and equals the order’s `vendorId` (see `vendorMayAccessThisOrder` in `firestore.rules`).
- **Rider location:** Riders may create/update their own document `riders/{request.auth.uid}` for live tracking (GPS / online flags); admin retains full control.
- **Vendors / products / banners / riders** writes are privileged (admin ± vendor where noted).
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

---

## 6. Future database evolution (recommended)

1. **`device_tokens` + Cloud Functions** — Persist FCM tokens per user doc for transactional notifications; keep topics for broadcasts.
2. **`notifications` subcollection** — `customers/{uid}/notifications` vs top-level; align with query patterns and retention.
3. **Payment expansion** — New `paymentMethod` values, `paymentStatus`, gateway refs; rules must move beyond COD-only validation.
4. **Coupon integrity** — Server-side validation (Cloud Function or backend) before trusting `discount` / `couponCode` on orders.
5. **Multi-vendor carts** — Today cart assumes single `storeId`; schema already per-line `storeId` but placement uses first item only — future split orders or merged delivery fee model.
6. **Product schema** — Formalize `sizes[]`, `extras[]` in Firestore to match cart line shape; retire demo tabs or load tabs from `category` / flags.
7. **`admins` collection** — If introduced for audit logs, document denormalization vs `customers` to avoid drift.
8. **Analytics / reporting** — BigQuery export or aggregate collections for vendor dashboards (avoid heavy client queries).
9. **Indexes** — Add composite indexes when adding `where` + `orderBy` on new fields (e.g. `vendorId` + `createdAt` for store order boards).
10. **Geospatial** — If querying “vendors near me” at scale, evaluate GeoFirestore or precomputed zones in addition to storing `GeoPoint`.

---

## 7. How to keep this document accurate

After schema or rules changes, update:

- `firebase_collections.dart` (names)
- `firestore.rules` (authoritative validation)
- This file **field tables** and **section 6** roadmap items

---

*Generated from repository analysis; Firestore is schemaless — unknown fields may exist in production documents that the app ignores.*
