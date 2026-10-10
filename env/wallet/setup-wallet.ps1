<#
.SYNOPSIS
  One-time setup of the Inji Wallet working copy used for the experiments.

.DESCRIPTION
  Checks prerequisites (Git, Node 18-22, JDK 17 or 21, Android SDK packages), clones
  mosip/inji-wallet at the pinned tag into a short path (Windows 260-character limit),
  creates the working branch and the baseline tag, points the wallet at the local
  Mimoto, and installs npm dependencies.

.EXAMPLE
  .\setup-wallet.ps1
  .\setup-wallet.ps1 -WalletDir D:\dev\inji-wallet
#>
param(
  [string]$WalletDir = "C:\dev\inji-wallet",
  [string]$Tag = "v0.22.1",
  [string]$Branch = "thesis/crypto-agility",
  [string]$StackDir = (Join-Path (Split-Path -Parent $PSScriptRoot) "stack")
)
$ErrorActionPreference = "Continue"
$ok = $true
function Pass($m) { Write-Host "  OK    $m" -ForegroundColor Green }
function Fail($m) { Write-Host "  MISS  $m" -ForegroundColor Red; $script:ok = $false }
function Warn($m) { Write-Host "  WARN  $m" -ForegroundColor Yellow }

Write-Host "Checking prerequisites" -ForegroundColor Cyan

# Git (also provides sh.exe for the npm postinstall script)
$git = Get-Command git -ErrorAction SilentlyContinue
if ($git) { Pass (git --version) } else { Fail "Git for Windows (https://git-scm.com/download/win)" }
$gitBin = if ($git) { Join-Path (Split-Path (Split-Path $git.Source)) "bin" } else { $null }

# Node 18 to 22
$node = Get-Command node -ErrorAction SilentlyContinue
if ($node) {
  $nv = (node --version).TrimStart("v"); $major = [int]$nv.Split(".")[0]
  if ($major -ge 18 -and $major -le 22) { Pass "Node $nv" } else { Fail "Node 18 to 22 required, found $nv (Node 22 LTS recommended)" }
} else { Fail "Node.js 22 LTS (https://nodejs.org/en/download, choose v22)" }

# JDK 17 or 21. Gradle 8.6 (used by the wallet) cannot run on Java 22+, and recent
# Android Studio releases bundle a newer JBR, so look for a Temurin 17/21 install first.
. "$PSScriptRoot\find-jdk.ps1"
$jdk = Find-SupportedJdk
if ($jdk) {
  $env:JAVA_HOME = $jdk.Home
  Pass "JDK $($jdk.Major) at $($jdk.Home)"
} else {
  Fail "JDK 17 or 21 (winget install -e --id EclipseAdoptium.Temurin.17.JDK). Android Studio's bundled JDK is too new for Gradle 8.6"
}

# Android SDK
$sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } elseif ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT } else { "$env:LOCALAPPDATA\Android\Sdk" }
if (Test-Path $sdk) {
  Pass "Android SDK at $sdk"
  $env:ANDROID_HOME = $sdk
  $sdkmanager = Get-ChildItem "$sdk\cmdline-tools" -Recurse -Filter sdkmanager.bat -ErrorAction SilentlyContinue | Select-Object -First 1
  $need = @{
    "platforms;android-35"     = "$sdk\platforms\android-35"
    "build-tools;35.0.0"       = "$sdk\build-tools\35.0.0"
    "ndk;21.4.7075529"         = "$sdk\ndk\21.4.7075529"
    "platform-tools"           = "$sdk\platform-tools\adb.exe"
  }
  $missing = @($need.Keys | Where-Object { -not (Test-Path $need[$_]) })
  if ($missing.Count -eq 0) { Pass "SDK packages: android-35, build-tools 35.0.0, NDK 21.4.7075529, platform-tools" }
  elseif ($sdkmanager) {
    Warn "Installing SDK packages: $($missing -join ', ')"
    cmd /c "echo y| `"$($sdkmanager.FullName)`" --licenses" | Out-Null
    & $sdkmanager.FullName @missing
  } else { Fail "SDK packages $($missing -join ', '). Install 'Android SDK Command-line Tools' in Android Studio > SDK Manager > SDK Tools, then rerun" }
} else { Fail "Android SDK not found at $sdk. Open Android Studio once and finish the setup wizard (Standard install) to download it" }

if (-not $ok) { Write-Host "`nFix the MISS items and rerun." -ForegroundColor Red; exit 1 }

# Clone (short path: Windows 260-char limit bites node_modules + Gradle/CMake)
if (-not (Test-Path "$WalletDir\.git")) {
  Write-Host "`nCloning inji-wallet $Tag into $WalletDir" -ForegroundColor Cyan
  New-Item -ItemType Directory -Force -Path (Split-Path $WalletDir) | Out-Null
  git -c core.longpaths=true clone --filter=blob:none --branch $Tag https://github.com/mosip/inji-wallet.git $WalletDir
  if ($LASTEXITCODE -ne 0) { exit 1 }
  git -C $WalletDir config core.longpaths true
  git -C $WalletDir config core.autocrlf input
  git -C $WalletDir switch -c $Branch
  git -C $WalletDir tag thesis-baseline
} else { Warn "$WalletDir already exists, skipping clone" }

Set-Location $WalletDir

# local.properties for Gradle
"sdk.dir=$($env:ANDROID_HOME.Replace('\','\\').Replace(':','\:'))" | Set-Content android\local.properties -Encoding ascii

# .env -> local Mimoto through the tunnel
& "$PSScriptRoot\sync-wallet-env.ps1" -WalletDir $WalletDir -StackDir $StackDir

# npm install. postinstall needs sh (from Git); GITHUB_ACTIONS skips the talisman hook download.
Write-Host "`nInstalling npm dependencies (several minutes)" -ForegroundColor Cyan
if ($gitBin -and (Test-Path "$gitBin\sh.exe")) { $env:Path = "$gitBin;$env:Path" }
$env:GITHUB_ACTIONS = "true"
npm ci --no-audit --no-fund
if ($LASTEXITCODE -ne 0) { Write-Host "npm ci failed" -ForegroundColor Red; exit 1 }

Write-Host "`nWallet workspace ready at $WalletDir on branch $Branch (baseline tag: thesis-baseline)." -ForegroundColor Green
Write-Host "Next: .\run-wallet.ps1" -ForegroundColor Cyan
