<#
.SYNOPSIS
  Records wallet (adb logcat) and server (Certify, nginx, Mimoto) logs for one experiment run.

.DESCRIPTION
  Clears the phone's log buffer, then streams logcat to the screen and to a file until
  Ctrl+C. On exit it saves the docker logs of certify, certify-nginx and mimoto-service
  for the same time window. Output: evidence\<yyyy-MM-dd>-<Name>\.
  adb is taken from the Android SDK, so it does not need to be on PATH.

.EXAMPLE
  .\capture-logs.ps1 -Name first-issuance
  (then run ..\stack\stack.ps1 issue-offer in another window, scan, and press Ctrl+C)
#>
param(
  [string]$Name = "wallet-run",
  [string]$RepoRoot = (Split-Path (Split-Path $PSScriptRoot))
)
$sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { "$env:LOCALAPPDATA\Android\Sdk" }
$adb = Join-Path $sdk "platform-tools\adb.exe"
if (-not (Test-Path $adb)) { Write-Host "adb not found at $adb (install 'Android SDK Platform-Tools')" -ForegroundColor Red; exit 1 }

$out = Join-Path $RepoRoot ("evidence\{0}-{1}" -f (Get-Date -Format "yyyy-MM-dd"), $Name)
New-Item -ItemType Directory -Force -Path $out | Out-Null

$dev = & $adb devices | Select-String "\tdevice$"
if (-not $dev) { Write-Host "No phone connected (adb devices shows none). Check USB debugging." -ForegroundColor Red; exit 1 }

$start = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
& $adb logcat -c
Write-Host "Recording to $out  (started $start UTC)." -ForegroundColor Cyan
Write-Host "Now: run issue-offer, scan in the wallet, WAIT for the result on the phone, then press Ctrl+C here." -ForegroundColor Cyan
try {
  # ReactNativeJS carries the wallet's JS logs (state machines, network errors);
  # warnings and errors from everything else catch keystore and native failures.
  # USF (Pixel sensor service) floods the log with flicker warnings and is silenced.
  # Written as UTF-8 (Tee-Object in Windows PowerShell 5.1 writes UTF-16).
  $writer = New-Object System.IO.StreamWriter((Join-Path $out "logcat.txt"), $false, (New-Object System.Text.UTF8Encoding($false)))
  $writer.AutoFlush = $true
  & $adb logcat -v threadtime ReactNativeJS:V ReactNative:V USF:S '*:W' | ForEach-Object { $writer.WriteLine($_); $_ }
} finally {
  if ($writer) { $writer.Close() }
  foreach ($c in "certify", "certify-nginx", "mimoto-service", "verify-service", "verify-ui") {
    docker logs --since $start --timestamps $c 2>&1 | ForEach-Object { "$_" } | Out-File (Join-Path $out "$c.log") -Encoding utf8
  }
  & $adb shell getprop ro.product.model  | Out-File (Join-Path $out "device.txt") -Encoding utf8
  & $adb shell getprop ro.build.version.release | Out-File (Join-Path $out "device.txt") -Append -Encoding utf8
  Write-Host "`nSaved logcat and server logs to $out" -ForegroundColor Green
}
