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
    ├── dashboard/            # Map home, online state, stats
    ├── delivery_requests/    # Nearby job offer overlay
    ├── earnings/             # Wallet, charts, cash remit, withdrawals
    ├── history/              # Delivered orders + rides
    ├── jobs/                 # Jobs tab (active, open pool, rides)
    ├── notifications/        # In-app rider inbox
    ├── orders/               # Repository, domain, detail
    ├── presence/             # riders/{uid} online flag
    ├── profile/              # Profile, avatar, settings
    ├── shell/                # Bottom nav + lifecycle wrappers
    ├── trip/                 # Active shop delivery + map navigation
    └── trips/                # Passenger rides + ride navigation
```

Each feature follows **data → domain → presentation** where applicable.

## Authentication

| Path | Screen |
|------|--------|
| `/auth/splash` | Splash → routes by session |
| `/auth/onboarding` | 3-slide intro (first launch) |
| `/auth/login` | Phone number → SMSlenz OTP |
| `/auth/otp` | 6-digit verification |
| `/auth/register` | Rider onboarding (personal, docs, vehicle) |

**Registration** writes `riders/{uid}` with NIC, vehicle, photos, `registrationComplete: true` after phone OTP.  
**Login:** SMSlenz OTP via Cloud Functions (`requestPhoneOtp` / `verifyPhoneOtp`) → Firebase custom token.

## Routing

| Path | Screen |
|------|--------|
| `/auth/login` | Sign in |
| `/auth/register` | Rider registration |
| `/home` | Shell tabs: Home, Jobs, Earnings, Profile |
| `/order/:orderId` | Order detail |
| `/trip/:orderId` | Active shop delivery map |
| `/ride/:tripId` | Active passenger ride map |
| `/history` | Delivery + ride history |
| `/notifications` | Rider inbox |
| `/earnings/transactions` | Wallet ledger |
| `/settings` | Availability, push prefs, appearance |
| `/profile/edit` | Edit profile |

Incoming delivery offers use a **global bottom overlay** (not a dedicated route).

Auth redirect: unsigned users → login; signed-in on auth routes → `/home`.

## Firebase services

- **FirebaseAuthService** — auth state / sign-out helpers (OTP sign-in lives in `RiderAuthRepository`)
- **FirebaseFirestoreService** — collection access wrapper
- **FirebaseStorageService** — `riders/{uid}/avatar.jpg`
- **FirebaseMessagingService** — permissions, topic `mnd_rider_jobs`, `device_tokens` sync

Repositories (`RiderOrdersRepository`, `RiderPresenceRepository`, etc.) use Firestore via Riverpod providers.

## Firestore (rider flows)

- **`riders/{uid}`** — profile, `online`, live location
- **`rider_locations/{uid}`** — public GPS for customer tracking
- **`orders`** — `openForRiders` + `status: ready` pool; claim sets `assignedRiderId`, `out_for_delivery`
- **`trips`** — passenger rides (`searching` → `accepted` → …)
- **`riders/{uid}/notifications`** — in-app inbox
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

For road-following (not straight-line) routes on the live trip map, the same
`GOOGLE_MAPS_KEY` also needs to reach Dart (the Directions API call can't
read `android/local.properties`). Run via `./run_dev.ps1` (reads the key from
`android/local.properties` and passes `--dart-define=GOOGLE_MAPS_KEY=...`
automatically) instead of a bare `flutter run`. Without the define, the map
falls back to a straight line between points.

## Dark / light mode

Toggle in **Profile**. Preference stored in `SharedPreferences` (`mnd_rider_theme_mode`).
