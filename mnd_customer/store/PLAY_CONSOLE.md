# Play Console — MND Customer (`com.mnd.mnd_customer`)

## Before first upload

1. **Firebase Android app (`com.mnd.mnd_customer` only)**
   - Firebase Console → Project `mnd-masterndelivery` → Project settings → Your apps
   - Keep only Android app `com.mnd.mnd_customer` for this customer app
   - **Delete** legacy Android app `com.example.mnd_delivery_app` if it still exists (unused)
   - On `com.mnd.mnd_customer`, add fingerprints from `android/firebase-sha-fingerprints.txt`:
     - debug SHA-1 + SHA-256
     - upload SHA-1 + SHA-256
   - Download fresh `google-services.json` → replace `android/app/google-services.json`
   - Restrict the **Maps SDK key** (`android/local.properties`) to package `com.mnd.mnd_customer` + those SHA fingerprints. **Do not** apply this same app-restriction to the Dart-side `GOOGLE_MAPS_KEY` in `dart_defines.json` — it's used for direct Directions API HTTP calls, which that restriction blocks (`REQUEST_DENIED`) even though the map itself keeps working. Use a separate key (API-restricted to Directions API only, no app restriction) for `dart_defines.json`.
   - After first Play upload: also add **Play App Signing** SHA-1/256 from Play Console → App signing

2. **Host legal pages**
   - Live on Firebase Hosting:
     - Privacy: https://mnd-customer-legal.web.app/privacy/
     - Terms: https://mnd-customer-legal.web.app/terms/
   - Paste the privacy URL into Play Console → App content → Privacy policy

3. **Deploy Firestore rules** (self-delete for accounts):
   ```bash
   firebase deploy --only firestore:rules
   ```

4. **Upload keystore**
   - Local (gitignored): `android/upload-keystore.jks` + `android/key.properties`
   - Back up both offline. Losing the upload key blocks updates unless you use Play App Signing recovery.

5. **Build**
   ```bash
   flutter build appbundle --release --dart-define-from-file=dart_defines.json --dart-define=APP_ENV=prod
   ```
   Admin UI is **off** unless you add `--dart-define=INCLUDE_ADMIN=true` (do not ship that to Play).
   **Do not drop `--dart-define-from-file=dart_defines.json`** — without it the shipped build has no `GOOGLE_MAPS_KEY`, so ride/order route lines silently never show for any Play Store user (the map still renders, so this is easy to miss when spot-checking the build before upload).

## Play Console forms

- **Data safety**: phone, name, email, photos, approximate + precise location, device IDs / push tokens; purposes = app functionality / account management; collected, not sold.
- **Account deletion**: Settings → Delete account (in-app).
- **Content rating**: include user-generated content (jobs).
- **Payments**: Job posting credits are **not** sold in-app. No WhatsApp/Play Billing purchase CTA — admins grant `jobPostCredits` from the web dashboard after offline arrangement. Food orders = COD; rides may use external PayHere (declare financial features as needed).
- **Ads**: declare no ads if you do not show ads (confirm Advertising ID if any SDK collects it).

## Store listing

- App name: MND Delivery  
- Package: `com.mnd.mnd_customer`  
- Icon: `assets/app_icon.png`  
- Screenshots: capture from release build on a phone
