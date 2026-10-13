<#
.SYNOPSIS
  Locates a JDK that Gradle 8.6 can run on (major version 17 to 21).

.DESCRIPTION
  Candidates, in order: JAVA_HOME; installs registered by Eclipse Adoptium, JavaSoft and
  Microsoft in the registry; JDK folders under common vendor directories in Program Files;
  java.exe on PATH; Android Studio's bundled JBR. The version is read from the JDK's
  'release' file (no process start), falling back to scanning all lines of 'java -version'
  (the first line can be "Picked up JAVA_TOOL_OPTIONS").
  Returns @{ Home; Major } for the first match, or $null.
  Call Show-JdkCandidates to list everything found, for diagnosis.
#>
function Get-JdkMajor($jdkHome) {
  if (-not $jdkHome) { return $null }
  if (-not (Test-Path (Join-Path $jdkHome "bin\javac.exe"))) { return $null }   # JDK, not JRE
  $release = Join-Path $jdkHome "release"
  if (Test-Path $release) {
    $line = Get-Content $release | Where-Object { $_ -like 'JAVA_VERSION=*' } | Select-Object -First 1
    if ($line -match '"(\d+)') { return [int]$Matches[1] }
  }
  $java = Join-Path $jdkHome "bin\java.exe"
  $out = cmd /c "`"$java`" -version 2>&1"
  foreach ($l in $out) { if ($l -match 'version "(\d+)') { return [int]$Matches[1] } }
  return $null
}

function Get-JdkCandidates {
  $c = New-Object System.Collections.Generic.List[string]
  if ($env:JAVA_HOME) { $c.Add($env:JAVA_HOME) }
  foreach ($key in @("HKLM:\SOFTWARE\Eclipse Adoptium\JDK", "HKLM:\SOFTWARE\JavaSoft\JDK", "HKLM:\SOFTWARE\Microsoft\JDK")) {
    if (Test-Path $key) {
      Get-ChildItem $key -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        $p = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
        if ($p.Path) { $c.Add($p.Path.TrimEnd('\')) }
        if ($p.JavaHome) { $c.Add($p.JavaHome.TrimEnd('\')) }
      }
    }
  }
  foreach ($pf in @($env:ProgramFiles, ${env:ProgramFiles(x86)}) | Where-Object { $_ }) {
    foreach ($vendor in @("Eclipse Adoptium", "Microsoft", "Java", "Zulu", "Amazon Corretto", "BellSoft", "OpenJDK")) {
      $root = Join-Path $pf $vendor
      if (Test-Path $root) {
        Get-ChildItem $root -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'jdk|zulu|corretto' } |
          Sort-Object Name -Descending | ForEach-Object { $c.Add($_.FullName) }
      }
    }
  }
  Get-Command java.exe -All -ErrorAction SilentlyContinue | ForEach-Object { $c.Add((Split-Path (Split-Path $_.Source))) }
  $c.Add("C:\Program Files\Android\Android Studio\jbr")
  return $c | Select-Object -Unique
}

function Find-SupportedJdk {
  foreach ($h in Get-JdkCandidates) {
    $major = Get-JdkMajor $h
    if ($major -ge 17 -and $major -le 21) { return @{ Home = $h; Major = $major } }
  }
  return $null
}

function Show-JdkCandidates {
  foreach ($h in Get-JdkCandidates) {
    $m = Get-JdkMajor $h
    $tag = if (-not (Test-Path $h)) { "missing" } elseif (-not $m) { "not a JDK" } else { "Java $m" }
    Write-Host ("  {0,-10} {1}" -f $tag, $h)
  }
}
