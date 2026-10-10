<#
.SYNOPSIS
  Builds and launches the Inji Wallet debug build on a USB phone (preferred) or emulator.
#>
param(
  [string]$WalletDir = "C:\dev\inji-wallet",
  [string]$StackDir = (Join-Path (Split-Path -Parent $PSScriptRoot) "stack")
)
$ErrorActionPreference = "Continue"
$sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { "$env:LOCALAPPDATA\Android\Sdk" }
$env:ANDROID_HOME = $sdk
. "$PSScriptRoot\find-jdk.ps1"
$jdk = Find-SupportedJdk
if (-not $jdk) { Write-Host "No JDK 17 or 21 found. Run setup-wallet.ps1 first." -ForegroundColor Red; exit 1 }
$env:JAVA_HOME = $jdk.Home
$adb = "$sdk\platform-tools\adb.exe"

& "$PSScriptRoot\sync-wallet-env.ps1" -WalletDir $WalletDir -StackDir $StackDir

# Device: prefer a USB phone (easier QR scanning), else boot the first emulator
$devices = & $adb devices | Select-String "\tdevice$"
if (-not $devices) {
  $avd = & "$sdk\emulator\emulator.exe" -list-avds | Select-Object -First 1
  if (-not $avd) { Write-Host "No phone and no emulator. Plug in a phone with USB debugging, or create an AVD in Android Studio > Device Manager." -ForegroundColor Red; exit 1 }
  Write-Host "Booting emulator $avd" -ForegroundColor Cyan
  Start-Process "$sdk\emulator\emulator.exe" -ArgumentList "-avd", $avd
  & $adb wait-for-device
  do { Start-Sleep 3; $boot = (& $adb shell getprop sys.boot_completed).Trim() } until ($boot -eq "1")
}
& $adb devices

# Metro in its own window (reset cache so .env changes are picked up)
Start-Process powershell -ArgumentList "-NoExit", "-Command", "Set-Location '$WalletDir'; npx react-native start --reset-cache"
Start-Sleep 5

Set-Location $WalletDir
& $adb reverse tcp:8081 tcp:8081 | Out-Null
npx react-native run-android --mode=residentappDebug --active-arch-only
