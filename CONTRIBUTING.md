# Contributing

## Before you deploy

There is no CI-driven auto-deploy in this repo — `firebase deploy` is run
manually from a dev machine after CI has gone green on `main`
(`.github/workflows/ci.yml`). Run this checklist yourself before deploying;
CI catches regressions, it does not deploy anything.

### mnd_customer (web)

1. `cd mnd_customer && flutter analyze` — zero issues.
2. `flutter test` — VM tests pass.
3. `flutter test --platform chrome` — web-compiled tests pass. **Do not
   skip this.** Some bugs (e.g. dart2js truncating bitwise `~`/`<<` to an
   unsigned 32-bit result) only show up once compiled to JS and are
   invisible to step 2 — see `test/features/rides/ride_directions_service_test.dart`
   for the real example that shipped to production before this checklist
   existed.
4. `flutter build web --release --dart-define-from-file=dart_defines.json --dart-define=APP_ENV=prod`
5. Confirm the Maps API key actually got embedded in the build — a silent
   drop here renders no route lines or map tiles for any user:
   `grep -c "<a short, memorable substring of your GOOGLE_MAPS_KEY value>" build/web/main.dart.js`
   (should report `1`, not `0`).
6. `firebase deploy --only hosting:web`
7. Open the live site and smoke-test the exact feature you changed (e.g.
   request a ride and confirm the route line follows real roads).

### functions

1. `cd functions && npm run build && npm test`
2. `firebase deploy --only functions,firestore:rules,firestore:indexes`
3. Smoke-test the deployed endpoint/flow in the live app.

## Git workflow

Commit only the files you actually touched — never `git add -A` /
`git add .` in this repo, since the working tree tends to carry unrelated
work-in-progress alongside whatever you're fixing. Push straight to `main`;
CI (`.github/workflows/ci.yml`) runs automatically on the push and reports
pass/fail on the commit in GitHub. Treat a red CI run as "do not deploy
this" until it's fixed.
