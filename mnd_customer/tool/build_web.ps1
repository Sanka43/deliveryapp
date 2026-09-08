# Build optimized Flutter web release for Firebase Hosting (mnd.lk).
# Usage (from mnd_customer):
#   powershell -File tool/build_web.ps1
#   powershell -File tool/build_web.ps1 -Wasm
#
# Default: dart2js + CanvasKit (stable).
# Pass -Wasm to opt into dart2wasm/skwasm (faster cold start on modern
# browsers) — currently BROKEN: cloud_firestore_web 4.4.12's JS interop
# crashes the dart2wasm compiler (null-check in Translator.translateStorageType).
# Fixing it for real means upgrading cloud_firestore/firebase_core and friends
# to their latest majors (5.x->6.x, 3.x->4.x), which is a breaking change
# across auth/firestore/storage/messaging/functions in all three apps and
# needs its own regression pass — not a one-line fix. Until then, build
# without -Wasm.

param(
  [switch]$CanvasKit,
  [switch]$Wasm,
  [string]$GoogleMapsKey = ""
)

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

if (-not $GoogleMapsKey) {
  $dartDefines = Join-Path (Get-Location) "dart_defines.json"
  if (Test-Path $dartDefines) {
    try {
      $GoogleMapsKey = (Get-Content $dartDefines -Raw | ConvertFrom-Json).GOOGLE_MAPS_KEY
    } catch {}
  }
}
if (-not $GoogleMapsKey) {
  $localProps = Join-Path (Get-Location) "android\local.properties"
  if (Test-Path $localProps) {
    $line = Get-Content $localProps | Where-Object { $_ -match '^\s*GOOGLE_MAPS_KEY\s*=' } | Select-Object -First 1
    if ($line) {
      $GoogleMapsKey = ($line -split '=', 2)[1].Trim()
    }
  }
}
if (-not $GoogleMapsKey) {
  Write-Error "GOOGLE_MAPS_KEY missing. Pass -GoogleMapsKey, or set it in dart_defines.json or android/local.properties."
  exit 1
}

$argsList = @(
  "build", "web",
  "--release",
  "--tree-shake-icons",
  "--pwa-strategy=offline-first",
  "--dart-define=APP_ENV=prod",
  "--dart-define=GOOGLE_MAPS_KEY=$GoogleMapsKey"
)

# -CanvasKit kept as a harmless no-op alias; CanvasKit is now the default.
if ($Wasm -and $CanvasKit) {
  Write-Error "Use either -Wasm or default/-CanvasKit, not both."
  exit 1
}
$useWasm = [bool]$Wasm

if ($useWasm) {
  $argsList += "--wasm"
  Write-Host "Building with dart2wasm / skwasm..."
} else {
  Write-Host "Building with dart2js + CanvasKit (chromium via flutter_bootstrap.js, default)..."
}

flutter @argsList
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

Write-Host "Done. Deploy with: firebase deploy --only hosting:web"
