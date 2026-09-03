# MND Rider — Firebase Security Rules

Production Firestore and Storage rules for the rider app live in the shared Firebase project and are deployed from **`mnd_customer`** (same project as customer/shop apps).

| Artifact | Path | Deploy |
|----------|------|--------|
| Firestore rules | `mnd_customer/firestore.rules` | `firebase deploy --only firestore:rules` |
| Storage rules | `mnd_customer/storage.rules` | `firebase deploy --only storage` |
| Indexes | `mnd_customer/firestore.indexes.json` | `firebase deploy --only firestore:indexes` |

---

## Authentication model

- Riders sign in with **Firebase Auth** via **phone OTP only** (SMSlenz Cloud Functions → custom token).
- Every protected path requires `request.auth != null`.
- **Self-access** is enforced with `request.auth.uid == riderId` (or `userId` on token/notification docs).
- **Admin** access uses `customers/{uid}.role` in `['admin','Admin','ADMIN']` (existing platform convention).

Riders are **not** stored in `customers/{uid}`; identity is `riders/{uid}` plus Auth UID.

---

## Role-based access

| Role | How rules detect it | Rider data access |
|------|---------------------|-------------------|
| Rider | `exists(riders/{auth.uid})` via `isRider()` | Own profile, wallet, ledger, withdrawals, inbox |
| Approved rider | `riders/{uid}.status` in `approved` \| `active` | Claim jobs, GPS writes, earnings writes |
| Customer | `customers/{uid}` + order `customerId` | Read own orders; read rider/location for tracking |
| Vendor | `vendors` + store scope | Order ops for their store |
| Admin | `customers/{uid}.role` | Full override |

**Approval gate:** Pending riders can register and edit profile, but cannot claim orders, publish GPS for delivery, or write wallet/earnings until an admin sets `status` to `approved` or `active`.

---

## Collections (logical → physical)

| User-facing name | Firestore path | Notes |
|------------------|----------------|-------|
| `riders` | `riders/{riderId}` | Profile, online, embedded GPS, FCM token |
| `orders` | `orders/{orderId}` | Shared with customer/shop |
| `notifications` | `notifications/{id}` | Global inbox (customer/vendor alerts from rider accept) |
| `earnings` | `riders/{id}/wallet/summary` | Wallet balances |
| `earnings` (aggregates) | `riders/{id}/earnings_aggregates/{periodKey}` | Daily/weekly/monthly |
| `transactions` | `riders/{id}/transactions/{id}` | Ledger |
| `withdrawals` | `riders/{id}/withdrawals/{id}` | Payout requests |
| Rider inbox (optional) | `riders/{id}/notifications/{id}` | Read/mark-read only; writes via Admin/CF |
| Live GPS (recommended) | `rider_locations/{riderId}` | High-frequency location split |

There is **no** top-level `earnings` or `transactions` collection.

---

## Firestore rules — by collection

### `riders/{riderId}`

| Operation | Who | Constraints |
|-----------|-----|-------------|
| **read** | Self, admin, any signed-in user | Signed-in read supports customer live-tracking; tighten later with `rider_locations` only if PII is a concern |
| **create** | Self (registration) | `role=rider`, `status=pending`, validated identity/vehicle fields |
| **update** | Self | **Cannot** change `status` or `role`; patches limited to profile, presence (`online`), GPS fields, or FCM token |
| **delete** | Admin only | — |

**Prevents:** Riders elevating themselves to `approved`, changing `uid`, or rewriting another rider’s doc.

### `riders/{riderId}/wallet`, `earnings_aggregates`, `transactions`, `withdrawals`

| Operation | Who | Constraints |
|-----------|-----|-------------|
| **read** | Self, admin | — |
| **create/update** | Approved self | Wallet/aggregate shape validation; transactions typed and bounded |
| **delete** | Admin | — |

**Transactions:**

- `delivery_earning`: positive amount, `completed`, doc id `earning_{orderId}` (idempotent delivery credit).
- `withdrawal`: negative amount, `pending`, must reference `withdrawalId`.

**Withdrawals:** Amount 500–500,000 LKR, `pending`, `payoutMethod` in `bank` \| `mobile`.

**Prevents:** Fabricating completed withdrawals, inflating balances without ledger shape, duplicate earning docs (id + rules).

### `riders/{riderId}/notifications`

| Operation | Who | Constraints |
|-----------|-----|-------------|
| **read** | Self, admin | — |
| **create** | Admin / Cloud Functions | Riders cannot forge inbox entries |
| **update** | Self | Only `read` flag |
| **delete** | Admin | — |

### `rider_locations/{riderId}`

| Operation | Who | Constraints |
|-----------|-----|-------------|
| **read** | Any signed-in | Customer map / dispatch |
| **write** | Approved self | `riderId`, lat/lng, `location` geopoint, `online` |

**Prevents:** Spoofing another rider’s GPS. Use this collection for high-frequency writes; keep `riders/{id}` for profile reads.

### `orders/{orderId}`

| Operation | Rider | Constraints |
|-----------|-------|-------------|
| **read** | Assigned rider (`riderId` or `assignedRiderId`) | Also open jobs via `isRider()` list queries |
| **update (claim)** | Approved rider | Only when `ready` + `openForRiders`; sets self as rider; **financial fields immutable** |
| **update (progress)** | Assigned approved rider | Only status + delivery timestamps; forward transitions only |

Allowed rider status path:  
`out_for_delivery` → `picked_up` \| `on_the_way` \| `delivered` → … → `delivered`.

**Prevents:** Changing `total`, `deliveryFee`, `items`, or reassigning to another rider after claim.

### `notifications/{notificationId}` (global)

| Operation | Rider | Constraints |
|-----------|-------|-------------|
| **create** | Rider | Only `type == rider_accepted'` with validated `userId`, `orderId`, title/body |
| **read/update/delete** | Owner / admin | Riders do not update global notifications |

### `device_tokens/{tokenId}`

| Operation | Who | Constraints |
|-----------|-----|-------------|
| **read/write/delete** | Owner | `userId == auth.uid`; token size bounds; `app` in allowed MND apps |

---

## Storage rules — `riders/{riderId}/**`

| Operation | Who | Constraints |
|-----------|-----|-------------|
| **read** | Any authenticated user | URLs also used in Firestore profile fields |
| **write** | `auth.uid == riderId` | Images only (`jpeg`/`png`/`webp`), max 10 MB |
| **delete** | Owner | Remove/replace photos |

**Prevents:** Anonymous uploads, non-image malware types, oversized files, writing to another rider’s folder.

Registration uploads photos **before** the Firestore rider doc exists; rules intentionally do **not** require a rider document for Storage writes.

---

## Threat summary

| Threat | Mitigation |
|--------|------------|
| Unauthenticated reads/writes | All paths require Auth (except none on these collections) |
| Rider impersonation | `isSelf(riderId)` on writes |
| Self-approval | `riderStatusUnchanged()` on rider profile updates |
| Order payout fraud | Immutable `deliveryFee` / `total` on rider order updates |
| Fake delivery completion | Status transition rules + app-side earning idempotency |
| Wallet inflation | Typed transactions, admin-only transaction update/delete |
| GPS spoofing | `rider_locations` and rider profile GPS patches only for `auth.uid` |
| Token hijacking | `device_tokens.userId` must match Auth UID |
| Notification spam | Rider create limited to `rider_accepted` template |

---

## Operational notes

1. **Deploy** after any rule change: from `mnd_customer`, run  
   `firebase deploy --only firestore:rules,storage`
2. **Approve riders** in Admin before they can go online, claim, or earn.
3. **Cloud Functions** (recommended): move FCM fan-out and rider inbox creates to the server; keep client rules strict.
4. **PII**: If `riders` read-by-any-authenticated-user is too open, switch customer tracking to `rider_locations` only and restrict `riders` read to self + admin + assigned-order customers (requires custom claims or order-scoped reads via Functions).

---

## Related docs

- [FIRESTORE_SCHEMA.md](./FIRESTORE_SCHEMA.md) — field-level schema and indexes
