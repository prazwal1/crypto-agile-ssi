<#
.SYNOPSIS
  Finds which request makes Certify log InsufficientAuthenticationException (known issue since 2026-10-09).

.DESCRIPTION
  Calls, one at a time, every Certify URL the stack scripts and health checks use, waits 2 s, and
  checks the Certify log written since that call for the exception. Writes
  evidence\<date>-certify-auth-diagnosis\result.txt and the matching log excerpts.
#>
. "$PSScriptRoot\common.ps1"
$out = Join-Path $RepoRoot ("evidence\{0}-certify-auth-diagnosis" -f (Get-Date -Format "yyyy-MM-dd"))
New-Item -ItemType Directory -Force -Path $out | Out-Null
$urls = @(
  "http://localhost:8090/v1/certify/actuator/health",
  "http://localhost:8090/v1/certify/actuator/info",
  "http://localhost:8090/v1/certify/.well-known/oauth-authorization-server",
  "http://localhost:8090/v1/certify/.well-known/openid-credential-issuer",
  "http://localhost:8090/v1/certify/.well-known/did.json",
  "http://localhost:8090/v1/certify/issuance/.well-known/openid-credential-issuer",
  "http://localhost:8090/v1/certify/",
  "http://localhost:8091/.well-known/did.json",
  "http://localhost:8091/.well-known/openid-credential-issuer",
  "http://localhost:8091/.well-known/oauth-authorization-server",
  "http://localhost:8091/.well-known/jwks.json"
)
$report = @()
Write-Section "Probing Certify URLs"
foreach ($u in $urls) {
  $since = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss")
  Start-Sleep -Milliseconds 1100
  $code = curl.exe -s -o NUL -w "%{http_code}" --max-time 15 $u
  Start-Sleep 2
  $hits = docker logs certify --since $since 2>&1 | Select-String "InsufficientAuthentication|Full authentication"
  $flag = if ($hits) { "EXCEPTION" } else { "-" }
  $line = "{0}  {1,-10} {2}" -f $code, $flag, $u
  Write-Host "  $line"; $report += $line
  if ($hits) { $hits | ForEach-Object { $_.Line } | Out-File (Join-Path $out ("hit-{0}.log" -f ($urls.IndexOf($u)))) -Encoding utf8 }
}
$report | Out-File (Join-Path $out "result.txt") -Encoding utf8
Write-Host "  Saved to $out"
