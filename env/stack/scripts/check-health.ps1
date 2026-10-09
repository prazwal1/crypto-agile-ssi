<#
.SYNOPSIS
  Reports container state, local endpoint status, public endpoint status and recent errors.
#>
. "$PSScriptRoot\common.ps1"

Write-Section "Containers"
docker compose ps --format "table {{.Name}}\t{{.Status}}" | Out-Host

Write-Section "Local endpoints"
$local = @(
  "http://localhost:8090/v1/certify/actuator/health",
  "http://localhost:8090/v1/certify/.well-known/oauth-authorization-server",
  "http://localhost:8091/.well-known/did.json",
  "http://localhost:8091/.well-known/openid-credential-issuer",
  "http://localhost:8091/.well-known/oauth-authorization-server",
  "http://localhost:8099/v1/mimoto/issuers",
  "http://localhost:3000",
  "http://localhost:3004"
)
foreach ($u in $local) { Write-Host ("  {0}  {1}" -f (Get-HttpStatus $u), $u) }

Write-Section "Public endpoints"
$pc = Get-EnvValue "PUBLIC_CERTIFY_URL"; $pm = Get-EnvValue "PUBLIC_MIMOTO_URL"
if ($pc) {
  foreach ($u in @("$pc/.well-known/did.json", "$pc/v1/certify/.well-known/openid-credential-issuer", "$pc/.well-known/oauth-authorization-server", "$pm/v1/mimoto/issuers")) {
    Write-Host ("  {0}  {1}" -f (Get-HttpStatus $u), $u)
  }
} else { Write-Note ".env has no public URLs yet; run .\stack.ps1 refresh-tunnels" }

Write-Section "Tunnel status"
foreach ($t in @("tunnel-certify", "tunnel-mimoto")) {
  $tail = cmd /c "docker logs --since 10m $t 2>&1"
  $state = if ($tail -match "Tunnel not found") { "DEAD (Tunnel not found)" } elseif ($tail -match "Registered tunnel connection") { "registered" } else { "no recent events" }
  Write-Host ("  {0,-15} {1}" -f $t, $state)
}

Write-Section "Recent Certify errors (last 15 min)"
cmd /c "docker logs --since 15m certify 2>&1" | Select-String -Pattern '"level":"ERROR"|Application run failed' |
  Select-Object -Last 5 | ForEach-Object { $s = $_.ToString(); $s.Substring(0, [Math]::Min(300, $s.Length)) } | Out-Host
