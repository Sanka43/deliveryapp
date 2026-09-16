# Runs the customer order-flow integration test on a booted emulator while
# recording the screen, then pulls the resulting mp4.
#
# Usage:
#   $env:DEMO_TEST_PHONE="<firebase test phone number>"
#   $env:DEMO_TEST_OTP="<fixed test otp>"
#   .\tool\record_order_demo.ps1
param(
  [string]$DeviceId = "emulator-5554",
  [string]$OutputDir = "$PSScriptRoot\..\demo_recordings",
  [string]$TestPhone = $env:DEMO_TEST_PHONE,
  [string]$TestOtp = $env:DEMO_TEST_OTP
)

if ([string]::IsNullOrWhiteSpace($TestPhone) -or [string]::IsNullOrWhiteSpace($TestOtp)) {
  Write-Error "TestPhone/TestOtp not set. Pass -TestPhone/-TestOtp or set `$env:DEMO_TEST_PHONE` / `$env:DEMO_TEST_OTP`."
  exit 1
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$remotePath = "/sdcard/order_demo.mp4"
$localPath = Join-Path $OutputDir "order_demo_$(Get-Date -Format yyyyMMdd_HHmmss).mp4"

adb -s $DeviceId wait-for-device

Write-Host "Starting screenrecord on $DeviceId..."
$recordProc = Start-Process -FilePath "adb" `
  -ArgumentList @("-s", $DeviceId, "shell", "screenrecord", "--bit-rate", "8000000", $remotePath) `
  -PassThru -NoNewWindow

Start-Sleep -Seconds 2

Write-Host "Running integration test..."
flutter test integration_test/order_flow_test.dart `
  -d $DeviceId `
  --dart-define=DEMO_TEST_PHONE=$TestPhone `
  --dart-define=DEMO_TEST_OTP=$TestOtp
$testExitCode = $LASTEXITCODE

Write-Host "Stopping screenrecord..."
adb -s $DeviceId shell "pkill -INT screenrecord"
Start-Sleep -Seconds 2
Stop-Process -Id $recordProc.Id -ErrorAction SilentlyContinue

Write-Host "Pulling recording to $localPath..."
adb -s $DeviceId pull $remotePath $localPath
adb -s $DeviceId shell rm $remotePath

if ($testExitCode -ne 0) {
  Write-Warning "Integration test exited with code $testExitCode — check the recording to see where it stopped."
}

Write-Host "Done: $localPath"
