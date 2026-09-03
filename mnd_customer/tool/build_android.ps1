# Build the Android app with the Maps key wired in — plain `flutter build`
# without --dart-define-from-file silently ships a working map (native SDK
# key comes from android/local.properties separately) but with NO route
# polylines anywhere (rides, order tracking), because the Directions API
# calls only read the GOOGLE_MAPS_KEY dart-define. See README.md.
#
# Usage (from mnd_customer):
#   powershell -File tool/build_android.ps1                # release .aab for Play Store (default)
#   powershell -File tool/build_android.ps1 -Apk            # release .apk (sideload / manual QA)
#   powershell -File tool/build_android.ps1 -Debug           # debug .apk for quick device testing

param(
  [switch]$Apk,
  [switch]$Debug,
  [string]$GoogleMapsKey = ""
)

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

if ($Debug -and -not $Apk) {
  $Apk = $true
}

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

$appEnv = if ($Debug) { "dev" } else { "prod" }

$argsList = @(
  "build",
  $(if ($Apk) { "apk" } else { "appbundle" }),
  $(if ($Debug) { "--debug" } else { "--release" }),
  "--dart-define=APP_ENV=$appEnv",
  "--dart-define=GOOGLE_MAPS_KEY=$GoogleMapsKey"
)

Write-Host "Building $(if ($Apk) { 'APK' } else { 'App Bundle' }) ($(if ($Debug) { 'debug' } else { 'release' }))..."
flutter @argsList
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

if ($Apk) {
  $outDir = if ($Debug) { "build\app\outputs\flutter-apk" } else { "build\app\outputs\flutter-apk" }
  Write-Host "Done. APK at $outDir\app-$(if ($Debug) { 'debug' } else { 'release' }).apk"
} else {
  Write-Host "Done. App Bundle at build\app\outputs\bundle\release\app-release.aab"
}
