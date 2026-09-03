# Runs the rider app with GOOGLE_MAPS_KEY wired into Dart (needed for the
# Directions API road-route calls; the native Maps SDK reads it separately
# via android/local.properties + manifest placeholders).
#
# Usage: ./run_dev.ps1 [-d <device-id>] [extra flutter run args...]

$ErrorActionPreference = 'Stop'
$propsPath = Join-Path $PSScriptRoot 'android/local.properties'

if (-not (Test-Path $propsPath)) {
    Write-Error "android/local.properties not found. Copy android/local.properties.example first."
}

$line = Get-Content $propsPath | Where-Object { $_ -match '^GOOGLE_MAPS_KEY=' } | Select-Object -First 1
if (-not $line) {
    Write-Error "GOOGLE_MAPS_KEY not set in android/local.properties."
}
$key = $line -replace '^GOOGLE_MAPS_KEY=', ''

flutter run --dart-define=GOOGLE_MAPS_KEY=$key @args
