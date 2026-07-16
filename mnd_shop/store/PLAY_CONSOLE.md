# MND Shop — Play Console submit pack

Use this file while filling Google Play Console. Code/packaging work is done;
these steps are Console-side or one-time ops.

## Ready artifacts

| Artifact | Location |
|----------|----------|
| App bundle (AAB) | `mnd_shop/build/app/outputs/bundle/release/app-release.aab` |
| Privacy policy URL | https://mnd-masterndelivery.web.app/legal/shop-privacy.html |
| Terms of Service URL | https://mnd-masterndelivery.web.app/legal/shop-terms.html |
| Feature graphic | `mnd_shop/store/feature-graphic.png` (crop/export to **1024 × 500** if needed) |
| High-res icon | `mnd_shop/assets/app_icon.png` (export **512 × 512** PNG) |

Rebuild AAB after code changes:

```bash
cd mnd_shop
flutter build appbundle --release
```

---

## 1. Store listing copy

**App name:** MND Vendor

**Short description (≤80 chars):**
```
Vendor app for MND Delivery — manage orders, products, and shop sales.
```

**Full description:**
```
MND Vendor is the official shop-owner app for MND Delivery.

Register your storefront, keep your catalogue up to date, accept incoming
customer orders, and track daily sales — all in one place.

What you can do
• Sign in securely and complete multi-step shop registration
• Accept, prepare, and complete orders in real time
• Manage products, prices, stock, and gallery images
• Open or close your shop for new orders
• View sales analytics and reports
• Get push alerts for new orders
• Switch language and notification preferences

Support: masterndelivery111@gmail.com · +94 77 637 6869
Privacy Policy: https://mnd-masterndelivery.web.app/legal/shop-privacy.html
```

**Category:** Business / Food & Drink (pick the closest Play category)

**Contact email:** masterndelivery111@gmail.com  
**Phone:** +94 77 637 6869

---

## 2. Declarations (must fill)

### Ads
- **Contains ads:** No

### Target audience
- Age: **18+** (business/vendor tool)
- Not primarily for children

### Content rating
- Complete IARC questionnaire (business utility; no user-generated social feed beyond order ops)

### App access
- Provide a **reviewer test account** (email + password) for an approved vendor shop.
- Notes for reviewers: “Use email/password on the login screen. After sign-in you can open Orders, Products, and Settings.”

### Data safety (declare collected)

| Data type | Collected | Shared | Purpose |
|-----------|-----------|--------|---------|
| Email / account | Yes | No* | App functionality, account management |
| Name / shop details | Yes | Limited (order fulfilment) | App functionality |
| Phone | Yes | Limited | App functionality, support |
| Approximate / precise location | Yes | Limited | Shop map pin / delivery ops |
| Photos | Yes | Yes (product/gallery URLs) | App functionality |
| Device / other IDs (FCM) | Yes | No* | App functionality (notifications) |
| App activity / orders | Yes | Limited | App functionality |

\*Infrastructure providers (Firebase/Google) process data as processors — follow Play’s wording for “shared with service providers” if prompted.

**Data encrypted in transit:** Yes  
**Users can request deletion:** Yes (via support / account closure)

---

## 3. Reviewer test account (create once)

1. Firebase Console → Authentication → add user (email/password).
2. Firestore → `vendors/{uid}` with fields such as:
   - `email`, `shopName`, `approvalStatus: "approved"`, `active: true`
   - plus any fields your app gate expects (see `vendor_account_gate_page.dart`).
3. Put the same email/password into Play Console → App content → App access.
4. Do **not** use a production shop that has real payouts if avoidable; use a QA shop.

---

## 4. Graphics still to capture on a device/emulator

Play requires phone screenshots (usually 2+). Capture after login:

1. Login screen  
2. Home / dashboard  
3. Orders board  
4. Products / catalog  
5. Settings  

Save under `mnd_shop/store/screenshots/` (create folder when capturing).

Upload:
- Feature graphic **1024 × 500**
- Icon **512 × 512**
- Phone screenshots

---

## 5. Upload path

1. Play Console → Create app (or open existing) → **MND Vendor** / `com.mnd.mnd_shop`
2. Paste privacy URL
3. Complete Data safety, rating, ads, audience, app access
4. Upload AAB to **Internal testing** first
5. Smoke-test install → promote to closed/open testing → production when ready

---

## 6. Ops checklist after each release

- [ ] Bump `version:` in `mnd_shop/pubspec.yaml` (`1.0.0+N`)
- [ ] `flutter build appbundle --release`
- [ ] Confirm `GOOGLE_MAPS_KEY` in `android/local.properties`
- [ ] `firebase deploy --only functions` if function code changed
- [ ] Upload AAB + release notes
