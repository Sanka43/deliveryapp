# MND Rider

Production Flutter app for MND delivery drivers — accept jobs, navigate trips, track earnings.

## Tech stack

| Layer | Package |
|-------|---------|
| UI | Flutter, Material 3, Google Fonts (Poppins) |
| State | Riverpod |
| Routing | go_router |
| Auth | Firebase Authentication |
| Data | Cloud Firestore |
| Media | Firebase Storage |
| Push | Firebase Cloud Messaging |
| Maps | google_maps_flutter + Google Maps API |
| Location | geolocator, permission_handler |

**Primary color:** `#2563EB`

## Folder structure (clean architecture)

```
lib/
├── main.dart                 # Entry → bootstrap + runApp
├── app.dart                  # MaterialApp.router, theme mode
├── firebase_options.dart
├── app/
│   ├── bootstrap/            # Firebase + FCM init
│   └── providers/            # DI: Firebase, theme, auth redirect
├── core/
│   ├── constants/            # Colors, spacing, routes, Firestore names
│   ├── theme/                # Light + dark Material 3 themes
│   ├── router/               # GoRouter config + auth guards
│   ├── services/
│   │   ├── firebase/         # Auth, Firestore, Storage, Messaging
│   │   └── maps/             # Map helpers
│   └── widgets/              # Reusable UI (cards, auth shell, stats)
└── features/
    ├── auth/                 # Login, register, session
    ├── dashboard/            # Online state + earnings summary
    ├── delivery_requests/    # Incoming job offer UI
    ├── earnings/             # Daily / weekly / monthly
    ├── history/              # Delivered orders
    ├── jobs/                 # Home tab (online toggle, orders)
    ├── orders/               # Repository, domain, detail
    ├── presence/             # riders/{uid} online flag
    ├── profile/              # Profile, avatar, settings
    ├── shell/                # Bottom nav + lifecycle wrappers
    └── trip/                 # Active delivery + map navigation
```

Each feature follows **data → domain → presentation** where applicable.

## Authentication

| Path | Screen |
|------|--------|
| `/auth/splash` | Splash → routes by session |
| `/auth/onboarding` | 3-slide intro (first launch) |
| `/auth/login` | Phone OTP or phone + password |
| `/auth/otp` | 6-digit verification |
| `/auth/register` | Full rider onboarding form |

**Registration** writes `riders/{uid}` with NIC, vehicle, photos, `registrationComplete: true`.  
**Login:** Firebase Phone Auth (OTP) or email/password derived from `+94` number.  
**Debug:** use dev OTP `123456` on login screen (debug builds only).

## Routing

| Path | Screen |
|------|--------|
| `/auth/login` | Sign in |
| `/auth/register` | Rider registration |
| `/home` | Shell (Jobs, Earnings, Profile) |
| `/order/:orderId` | Order detail |
| `/trip/:orderId` | Active trip (pass `RiderOrderDetail` as `extra` when possible) |
| `/history` | Delivery history |
| `/offer` | Full-screen incoming job (modal) |

Auth redirect: unsigned users → login; signed-in on auth routes → `/home`.

## Firebase services

- **FirebaseAuthService** — email/password sign-in and registration
- **FirebaseFirestoreService** — collection access wrapper
- **FirebaseStorageService** — `riders/{uid}/avatar.jpg`
- **FirebaseMessagingService** — permissions, topic `mnd_rider_jobs`, `device_tokens` sync

Repositories (`RiderOrdersRepository`, `RiderPresenceRepository`, etc.) use Firestore via Riverpod providers.

## Firestore (rider flows)

- **`riders/{uid}`** — profile, `online`, live location
- **`orders`** — `openForRiders` + `status: ready` pool; claim sets `assignedRiderId`, `out_for_delivery`
- **`device_tokens`** — FCM tokens per user

See repo root [DATABASE.md](../DATABASE.md) for full schema.

## Setup

1. Copy `android/local.properties.example` → `android/local.properties` and set `GOOGLE_MAPS_KEY` (same key as `mnd_customer` / `mnd_shop` if shared).
2. Ensure `firebase_options.dart` matches your Firebase project (`mnd-masterndelivery`).
3. Deploy Firestore indexes for rider queries (see `mnd_customer/firestore.indexes.json`).
4. Run:

```bash
cd mnd_rider
flutter pub get
flutter run
```

## Dark / light mode

Toggle in **Profile**. Preference stored in `SharedPreferences` (`mnd_rider_theme_mode`).
