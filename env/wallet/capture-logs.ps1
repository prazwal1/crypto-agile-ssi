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
Write-Host "Recording to $out  (started $start UTC). Do the test on the phone, then press Ctrl+C." -ForegroundColor Cyan
try {
  # ReactNativeJS carries the wallet's JS logs (state machines, network errors);
  # warnings and errors from everything else catch keystore and native failures.
  & $adb logcat -v threadtime ReactNativeJS:V ReactNative:V '*:W' | Tee-Object -FilePath (Join-Path $out "logcat.txt")
} finally {
  foreach ($c in "certify", "certify-nginx", "mimoto-service") {
    docker logs --since $start --timestamps $c *> (Join-Path $out "$c.log")
  }
  & $adb shell getprop ro.product.model  | Out-File (Join-Path $out "device.txt")
  & $adb shell getprop ro.build.version.release | Out-File (Join-Path $out "device.txt") -Append
  Write-Host "`nSaved logcat and server logs to $out" -ForegroundColor Green
}
