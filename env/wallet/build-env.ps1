<#
.SYNOPSIS
  Build environment for the wallet: keeps Gradle and npm caches next to the repo
  (not on C:) and caps Gradle resource use so the build does not saturate the laptop.

.DESCRIPTION
  Dot-source this file, then call Set-WalletBuildEnv. It sets GRADLE_USER_HOME and the
  npm cache under the thesis root (the folder that contains crypto-agile-ssi) and writes
  a user-level gradle.properties there. User-level properties override the wallet's own
  android/gradle.properties, so the wallet source stays unmodified.

  Added 2026-10-13 after the first laptop ran at 100% CPU/RAM during Android builds.
#>
$script:ThesisRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot))

function Set-WalletBuildEnv {
  param(
    [string]$HeapSize = "4g",     # Gradle daemon heap; raise to 6g on 32 GB RAM
    [int]$Workers = 4,            # parallel Gradle workers; keep below core count
    [string]$Abi = "arm64-v8a"    # Pixel 7; one ABI instead of four native builds
  )
  $gradleHome = Join-Path $script:ThesisRoot ".gradle"
  $npmCache   = Join-Path $script:ThesisRoot ".cache\npm"
  New-Item -ItemType Directory -Force -Path $gradleHome, $npmCache | Out-Null
  $env:GRADLE_USER_HOME = $gradleHome
  $env:npm_config_cache = $npmCache
  @(
    "# Written by env/wallet/build-env.ps1. Overrides the wallet's android/gradle.properties."
    "org.gradle.jvmargs=-Xmx$HeapSize -XX:MaxMetaspaceSize=1g -XX:+UseParallelGC -Dfile.encoding=UTF-8"
    "org.gradle.workers.max=$Workers"
    "org.gradle.parallel=true"
    "org.gradle.caching=true"
    "org.gradle.daemon=true"
    "org.gradle.vfs.watch=true"
    "kotlin.daemon.jvmargs=-Xmx2g"
    "reactNativeArchitectures=$Abi"
  ) | Set-Content (Join-Path $gradleHome "gradle.properties") -Encoding ascii
  Write-Host "  OK    GRADLE_USER_HOME=$gradleHome (heap $HeapSize, $Workers workers, ABI $Abi)" -ForegroundColor Green
}
