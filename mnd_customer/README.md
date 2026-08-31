# MND Delivery — Customer App

Flutter customer app for **MND Delivery** (`mnd_delivery_app`). Browse vendors, build a cart, checkout (cash on delivery), track orders, book rides, and browse jobs.

## Stack

- Flutter 3.3+, **Riverpod**, **go_router**
- **Firebase**: Auth (phone OTP), Firestore, FCM, Storage
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
| `rides` | Quote, cash booking, searching, live tracking, history |
| `jobs` | Browse, apply, post (credits), saved jobs |
| `offers` | Promo offers on home and store |
| `admin` | Lightweight ops UI (same APK behind flag; prefer separate admin app long-term) |

Architecture is feature-first (`data` / `domain` / `presentation`). State uses **Riverpod providers**, not Bloc.

## Setup

1. `cd mnd_customer`
2. `flutter pub get`
3. Add `GOOGLE_MAPS_KEY=...` to `android/local.properties` (Android Maps SDK) and to `ios/Flutter/Secrets.xcconfig` (iOS Maps SDK, copy from `Secrets.xcconfig.example`).
4. **Dart-side key (web Maps JS script + Directions API calls, used on every platform):** copy `dart_defines.example.json` → `dart_defines.json` and fill in the same `GOOGLE_MAPS_KEY`. This file is gitignored — never commit it.
   - **VS Code:** already wired — `.vscode/launch.json` passes `--dart-define-from-file=dart_defines.json` automatically, so `F5` / the Run panel just works.
   - **Android Studio / IntelliJ:** open Run/Debug Configurations for `lib/main.dart` and add `--dart-define-from-file=dart_defines.json` to "Additional run args".
   - **Command line:** `flutter run --dart-define-from-file=dart_defines.json`
   - Without this file, `flutter run` (with no flags) will show a **blank map on web** and **missing route polylines everywhere** (native Android/iOS map tiles still work off `local.properties`/`Secrets.xcconfig`, but the Directions API calls used for route previews do not — they only read the dart-define).
   - **Use a separate key from the Maps SDK one in step 3.** A key restricted "package name+SHA" (Android) or "bundle ID" (iOS) only authorizes the *native* Maps SDK — it does **not** authorize this Dart-side `Dio` HTTP call to the Directions API, which gets rejected with `REQUEST_DENIED` even though the key "works" for showing the map. Enable **Maps JavaScript API** and **Directions API** (and Geocoding if needed) on this key, and restrict it by **HTTP referrer** for web, or **API restriction only** (no app/package restriction) for the mobile Directions calls.
5. `flutter run`

Firebase config: `lib/firebase_options.dart`. Firestore rules and indexes live in this folder (`firestore.rules`, `firestore.indexes.json`). See repo root [`DATABASE.md`](../DATABASE.md).

## Guest browsing

Login offers **Continue as guest** — browse home, stores, cart, rides, and jobs. Guest mode is restored after app restart. **Sign in is required** to place an order, confirm a ride, apply/post jobs, or save jobs (cart, checkout, rides, and jobs show a sign-in action).

## Payments

Production path: **cash on delivery** (orders) and **cash** (rides) only. Card and wallet are not shown until a payment gateway is integrated.

## Tests

```bash
flutter test
```

Manual Android + Web smoke checklist (OTP carriers, checkout, rides, error UX): [`docs/MANUAL_QA.md`](docs/MANUAL_QA.md).

## Release build (Android)

1. Copy `android/key.properties.example` → `android/key.properties` and set your upload keystore paths.
2. Place your `.jks` file (never commit it).
3. Build:

```bash
flutter build appbundle --release --dart-define-from-file=dart_defines.json --dart-define=APP_ENV=prod
```

**Do not drop `--dart-define-from-file=dart_defines.json` from this command.** Without it, `GOOGLE_MAPS_KEY` is empty in the built app and route polylines (rides, order tracking) silently never show for any real user — the map itself still renders fine (native SDK reads `android/local.properties` separately), so this is easy to miss in a quick QA pass. In CI, generate `dart_defines.json` from a secret instead of committing it, or pass `--dart-define=GOOGLE_MAPS_KEY=...` directly.

Before deploying a web build in particular, see the checklist in [`../CONTRIBUTING.md`](../CONTRIBUTING.md) — it covers this same key-embedding check plus the `flutter test --platform chrome` step needed to catch web-only bugs.

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

## Play Store

See [`store/PLAY_CONSOLE.md`](store/PLAY_CONSOLE.md). Android applicationId is `com.mnd.mnd_customer`.
