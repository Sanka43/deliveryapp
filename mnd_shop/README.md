# mnd_shop (MND Vendor)

Flutter app for shop owners: register a storefront, manage products, accept orders, and view sales analytics.

## Features

- Email sign-in and multi-step shop registration (map pin, gallery, hours)
- Order board (new → kitchen → ready → completed) with in-app alerts
- Product catalog CRUD with image upload
- Live sales KPIs and charts from completed Firestore orders
- Profile, location, gallery, language, and notification settings
- Light / dark theme

## Setup

1. Install Flutter SDK (see root repo docs).
2. Configure Firebase (`firebase_options.dart` / platform configs).
3. Copy `android/local.properties.example` → `android/local.properties` and set `GOOGLE_MAPS_KEY` for map pin on Android.
4. iOS: set `GOOGLE_MAPS_KEY` in `ios/Flutter/Secrets.xcconfig` (see `Secrets.xcconfig.example`).

```bash
cd mnd_shop
flutter pub get
flutter run
```

## Tests

```bash
flutter test
```

## Play Console release checklist

Before uploading to Google Play Console:

1. Configure release signing:
   - Copy `android/key.properties.example` to `android/key.properties`.
   - Create or place the upload keystore referenced by `storeFile`.
   - Set the real `storePassword`, `keyAlias`, and `keyPassword`.
   - Keep `android/key.properties` and the keystore out of git.
2. Register the shop Android app in Firebase with package name `com.mnd.mnd_shop`.
3. Confirm `android/app/google-services.json` includes the `com.mnd.mnd_shop` client
   and the Google Services Gradle plugin is applied (already wired in this project).
4. Confirm `pubspec.yaml` version. Increase the build number for every Play upload.
5. Deploy public legal pages (required for Play Console privacy URL):

```bash
# from repo root
firebase deploy --only hosting:admin
```

   Play Console privacy policy URL:
   `https://mnd-masterndelivery.web.app/legal/shop-privacy.html`

   Terms (optional listing field):
   `https://mnd-masterndelivery.web.app/legal/shop-terms.html`
6. Confirm Cloud Functions password-reset debug OTP is off in production.
   Keep `functions/.env` as `SHOP_PASSWORD_RESET_DEBUG=false` (see `.env.example`).
   Redeploy after changing it:

```bash
firebase deploy --only functions
```

   The Functions emulator can still enable debug OTP with `SHOP_PASSWORD_RESET_DEBUG=1`
   for local QA only.
7. Prepare Play Console declarations:
   - Privacy policy URL (above)
   - Data safety form (location, photos, account, device/FCM)
   - App access / reviewer test account
   - Content rating
   - Target audience
   - Ads declaration: **No**
8. Ensure `GOOGLE_MAPS_KEY` is set in `android/local.properties` for release builds.
9. Build the signed app bundle:

```bash
flutter build appbundle --release
```

The Play upload artifact is written to `build/app/outputs/bundle/release/app-release.aab`.

Release builds enable R8 minify + resource shrinking (`android/app/build.gradle.kts`)
with Flutter/Firebase/Play Core keep rules in `android/app/proguard-rules.pro`.

## Play Console submit pack

See [`store/PLAY_CONSOLE.md`](store/PLAY_CONSOLE.md) for listing copy, Data safety
answers, reviewer-account steps, and graphics checklist.

Store assets:

- `store/feature-graphic.png` (1024×500)
- `store/icon-512.png` (512×512)
- `store/screenshots/` — capture phone screenshots here before upload
