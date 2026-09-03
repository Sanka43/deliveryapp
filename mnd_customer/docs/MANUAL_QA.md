# Customer app — Manual QA (Android + Web)

Use this checklist before release. Project: `mnd-masterndelivery`. Package: `com.mnd.mnd_customer`.

## How to run

### Android (physical device preferred for OTP)

```bash
cd mnd_customer
flutter pub get
# Maps: set GOOGLE_MAPS_KEY in android/local.properties
flutter devices
flutter run --dart-define=APP_ENV=staging
# Customer-facing check (closer to Play):
flutter run --release --dart-define=APP_ENV=prod
```

Confirm debug/release SHA-1 + SHA-256 for `com.mnd.mnd_customer` are in Firebase Console (see `android/firebase-sha-fingerprints.txt`).

### Web

```bash
cd mnd_customer
flutter run -d chrome --dart-define=APP_ENV=staging
# Prod-like:
# powershell -File tool/build_web.ps1
```

Authorized domains must include your hosting host (e.g. `mnd.lk`, `localhost` for local Chrome).

### Automated smoke (CI / local)

```bash
flutter test
```

---

## OTP / SMS (Sri Lanka carriers)

App code does **not** branch by carrier. Flow: Login → E.164 `+94…` → Cloud Function `requestPhoneOtp` (SMSlenz SMS) → OTP page → `verifyPhoneOtp` + custom token.

| Prefix (typical) | Carrier |
|------------------|---------|
| 070 / 071 | Mobitel |
| 077 / 076 | Dialog |
| 075 | Airtel |
| 078 | Hutch |

### If OTP works only on Mobitel

1. On a Dialog/Airtel/Hutch number: tap Continue and watch logs for `OTP codeSent` vs `OTP send failed`.
2. If **`codeSent` succeeds but SMS never arrives** → Firebase SMS gateway / carrier filtering. App cannot force delivery.
3. Firebase Console → Authentication → Phone:
   - Add **test phone numbers** for one Dialog + one Airtel number (proves Auth without real SMS).
   - Check SMS usage / quotas / region.
4. Confirm Android SHA fingerprints and web authorized domains.
5. Open a Firebase support / SMS region ticket for Sri Lanka Dialog/Airtel/Hutch non-delivery.

### In-app OTP UX (expected)

- Friendly send/verify errors only (no Firebase Console / SHA / error-code text in release).
- After countdown ends or after a Resend: hint about signal / Resend / slower networks.
- Wrong code / expired session → clear Resend guidance.

---

## Smoke checklist

Mark each on **Android** and **Web**. Log failures below with platform + steps.

### 1. Auth

- [ ] Guest browse home without sign-in
- [ ] Login with `+94` (strip leading `0`)
- [ ] OTP Mobitel — SMS arrives and verifies
- [ ] OTP Dialog — SMS arrives (or document Firebase carrier issue)
- [ ] OTP Airtel / Hutch — same
- [ ] Wrong OTP → friendly message
- [ ] Resend → new code works
- [ ] Web: reCAPTCHA / browser session OK
- [ ] Sign out

### 2. Home / catalog

- [ ] Banners, food, grocery, shops load
- [ ] Search + favorites
- [ ] Closed shop: browse OK, cannot order

### 3. Cart / checkout

- [ ] Multi-store add blocked with clear message
- [ ] Address / map pin (Android, iOS, and web with `--dart-define=GOOGLE_MAPS_KEY=...`)
- [ ] COD place order succeeds
- [ ] Coupon apply / reject
- [ ] Shop-closed gate at checkout

### 4. Orders

- [ ] History + detail
- [ ] Cancel when allowed
- [ ] Live tracking (if rider assigned)
- [ ] Errors show friendly text only (airplane mode)

### 5. Rides

- [ ] Quote → confirm → searching
- [ ] Cancel search
- [ ] History
- [ ] Errors show friendly text only

### 6. Profile

- [ ] Edit name / photo
- [ ] Saved addresses CRUD
- [ ] Language
- [ ] Notification toggles
- [ ] Settings / sign-out
- [ ] Account delete only on a disposable test account

### 7. Error UX gate

Force offline or deny location. UI must **not** show:

- `Exception:` / stack traces
- Firebase codes (`permission-denied`, `[cloud_firestore/…]`)
- Ops text (“Deploy Firestore rules”, “Firebase Console”, SHA fingerprints)

---

## Session log (2026-08-09)

| ID | Severity | Platform | Finding | Status |
|----|----------|----------|---------|--------|
| Q1 | P0 | All | Raw `e.toString()` / Firebase codes on rides, profile, settings, addresses, catalog, orders | **Fixed** — `userFacingError` wired through customer paths |
| Q2 | P1 | All | Auth OTP errors exposed Console / SHA / `(code)` to users | **Fixed** — mapped customer copy + `debugPrint` only |
| Q3 | P1 | All | OTP screen after `codeSent` with no SMS left users stuck | **Fixed** — SMS help hint after countdown / resend |
| Q4 | P0 | Android/Web | Dialog/Airtel/Hutch SMS may not arrive while Mobitel works | **Ops** — Firebase SMS / carrier; not app branching. Use test phones + Console/support |
| — | — | Local | `flutter test` (26 tests) | **Pass** |

### Remaining manual (needs real SIMs / devices)

Re-run checklist §1–§7 on a physical Android phone and Chrome (or hosted web). Especially multi-carrier OTP and a full COD order + ride on staging/prod.

---

## Related

- App README: [`../README.md`](../README.md)
- Play upload notes: [`../store/PLAY_CONSOLE.md`](../store/PLAY_CONSOLE.md)
- Error helper: [`../lib/core/utils/user_facing_error.dart`](../lib/core/utils/user_facing_error.dart)
