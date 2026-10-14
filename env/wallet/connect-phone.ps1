<#
.SYNOPSIS
  Gets an installed debug wallet past "Loading from localhost:8081" without rebuilding.

.DESCRIPTION
  1. Checks the phone is visible to adb (USB or wireless debugging).
  2. Starts Metro in its own window if nothing answers on port 8081.
  3. Restores the adb reverse forward for 8081 (wireless adb loses it on every reconnect).
  4. Force-stops and relaunches the wallet so it fetches the bundle again.
  Watch the Metro window: the first bundle after a cache reset takes 2 to 5 minutes.
#>
param(
  [string]$WalletDir = (Join-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot))) "inji-wallet"),
  [string]$Package = "io.mosip.residentapp"
)
$sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { "$env:LOCALAPPDATA\Android\Sdk" }
$adb = Join-Path $sdk "platform-tools\adb.exe"
if (-not (Test-Path $adb)) { Write-Host "adb not found at $adb" -ForegroundColor Red; exit 1 }

$dev = & $adb devices | Select-String "\tdevice$"
if (-not $dev) { Write-Host "No phone visible to adb. Reconnect USB or wireless debugging, then rerun." -ForegroundColor Red; exit 1 }
Write-Host "Phone: $($dev[0].Line.Split("`t")[0])" -ForegroundColor Green

$status = curl.exe -s --max-time 5 http://localhost:8081/status
if ($status -ne "packager-status:running") {
  Write-Host "Metro not running; starting it in a new window" -ForegroundColor Yellow
  Start-Process powershell -ArgumentList "-NoExit", "-Command", "Set-Location '$WalletDir'; npx react-native start"
  $t = 0
  do { Start-Sleep 3; $t += 3; $status = curl.exe -s --max-time 3 http://localhost:8081/status } until ($status -eq "packager-status:running" -or $t -ge 90)
  if ($status -ne "packager-status:running") { Write-Host "Metro did not start within 90 s; check its window for errors" -ForegroundColor Red; exit 1 }
}
Write-Host "Metro: running" -ForegroundColor Green

& $adb reverse tcp:8081 tcp:8081 | Out-Null
if (-not ((& $adb reverse --list) -match "tcp:8081")) { Write-Host "adb reverse failed" -ForegroundColor Red; exit 1 }
Write-Host "Port forward 8081: set" -ForegroundColor Green

& $adb shell am force-stop $Package
& $adb shell monkey -p $Package -c android.intent.category.LAUNCHER 1 | Out-Null
Write-Host "Wallet relaunched. Watch the Metro window for the bundling progress bar." -ForegroundColor Green
