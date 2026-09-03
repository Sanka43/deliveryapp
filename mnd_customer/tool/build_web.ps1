# Build optimized Flutter web release for Firebase Hosting (mnd.lk).
# Usage (from mnd_customer):
#   powershell -File tool/build_web.ps1
#   powershell -File tool/build_web.ps1 -CanvasKit
#
# Default: dart2wasm / skwasm (faster cold start on modern browsers).
# Pass -CanvasKit for the legacy dart2js + chromium CanvasKit build.

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

# -Wasm kept for backwards compatibility; WASM is now the default.
$useWasm = -not $CanvasKit
if ($Wasm -and $CanvasKit) {
  Write-Error "Use either default/WASM or -CanvasKit, not both."
  exit 1
}

if ($useWasm) {
  $argsList += "--wasm"
  Write-Host "Building with dart2wasm / skwasm (default)..."
} else {
  Write-Host "Building with dart2js + CanvasKit (chromium via flutter_bootstrap.js)..."
}

flutter @argsList
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

Write-Host "Done. Deploy with: firebase deploy --only hosting:web"
