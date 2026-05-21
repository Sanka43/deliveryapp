# MND Delivery — Customer App

Flutter customer app for **MND Delivery** (`mnd_delivery_app`). Browse vendors, build a cart, checkout (cash on delivery), and track orders.

## Stack

- Flutter 3.3+, **Riverpod**, **go_router**
- **Firebase**: Auth (phone OTP, Google), Firestore, FCM, Storage
- Maps: Google Maps, geolocator, geocoding

## Modules

| Module | Purpose |
|--------|---------|
| `auth` | Splash, onboarding, login, OTP, guest browsing, role gates |
| `customer` | Home, search, profile, addresses, banners, settings |
| `store` | Store menu (Firestore products) |
| `cart` | In-memory cart, delivery fee quote |
| `checkout` | Address, map pin, COD placement |
| `orders` | History, detail, cancellation, live rider map |
| `admin` | Lightweight ops UI (same APK; prefer separate admin app long-term) |

Architecture is feature-first (`data` / `domain` / `presentation`). State uses **Riverpod providers**, not Bloc.

## Setup

1. `cd mnd_customer`
2. `flutter pub get`
3. Add `GOOGLE_MAPS_KEY=...` to `android/local.properties` for map picker.
4. `flutter run`

Firebase config: `lib/firebase_options.dart`. Firestore rules and indexes live in this folder (`firestore.rules`, `firestore.indexes.json`). See repo root [`DATABASE.md`](../DATABASE.md).

## Guest browsing

Login offers **Continue as guest** — browse home, stores, and cart. **Sign in is required** to place an order (cart and checkout show a sign-in action).

## Payments

Production path: **cash on delivery** only. Card and wallet are disabled in UI until a payment gateway is integrated.

## Tests

```bash
flutter test
```

## Release build (Android)

1. Copy `android/key.properties.example` → `android/key.properties` and set your upload keystore paths.
2. Place your `.jks` file (never commit it).
3. Build:

```bash
flutter build appbundle --release --dart-define=APP_ENV=prod
```

Debug / staging:

```bash
flutter run --dart-define=APP_ENV=staging
```

`APP_ENV` controls the in-app title suffix (`Dev`, `Staging`, or plain `MND Delivery` for prod).

### Push notifications

- Device token is saved to `customers/{uid}.fcmToken` on sign-in.
- Order/promo toggles subscribe to FCM topics `mnd_order_updates` and `mnd_promotions`.
- FCM data payload should include `orderId` (or `order_id`) to open order detail; optional `screen=tracking` for live map.
- In-app: Firestore order status changes show a snackbar while the app is open.

## Related apps

- **Vendor:** `../mnd_shop`
- **Rider:** `../mnd_rider`
