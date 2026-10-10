<#
.SYNOPSIS
  Locates a JDK that Gradle 8.6 can run on (major version 17 to 21).

.DESCRIPTION
  Checks JAVA_HOME first, then common install locations (Eclipse Adoptium, Microsoft,
  Android Studio JBR). Returns @{ Home; Major } for the first match, or $null.
#>
function Get-JdkMajor($jdkHome) {
  $java = Join-Path $jdkHome "bin\java.exe"
  if (-not (Test-Path $java)) { return $null }
  $line = (cmd /c "`"$java`" -version 2>&1" | Select-Object -First 1)
  if ($line -match '"(\d+)(\.\d+)*') { return [int]$Matches[1] }
  return $null
}

function Find-SupportedJdk {
  $candidates = @()
  if ($env:JAVA_HOME) { $candidates += $env:JAVA_HOME }
  foreach ($root in @("C:\Program Files\Eclipse Adoptium", "C:\Program Files\Microsoft", "C:\Program Files\Java")) {
    if (Test-Path $root) {
      $candidates += Get-ChildItem $root -Directory -Filter "jdk-*" | Sort-Object Name -Descending | ForEach-Object { $_.FullName }
    }
  }
  $candidates += "C:\Program Files\Android\Android Studio\jbr"
  foreach ($c in $candidates) {
    $major = Get-JdkMajor $c
    if ($major -ge 17 -and $major -le 21) { return @{ Home = $c; Major = $major } }
  }
  return $null
}
