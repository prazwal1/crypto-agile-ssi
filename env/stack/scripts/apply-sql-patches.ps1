<#
.SYNOPSIS
  Applies every sql\patches\*.sql file, in name order, to the running database.
  A patch targets inji_certify unless its header has a line "-- database: <name>".

.DESCRIPTION
  Patches change configuration data only and are written to be safe to re-run.
  Certify, nginx and verify-service are restarted afterwards so cached configuration is reloaded.
#>
. "$PSScriptRoot\common.ps1"

Write-Section "Applying SQL patches"
Get-ChildItem .\sql\patches\*.sql | Sort-Object Name | ForEach-Object {
  $sql = Get-Content $_.FullName -Raw
  $db = if ($sql -match '(?m)^--\s*database:\s*(\S+)') { $Matches[1] } else { "inji_certify" }
  Write-Host "  $($_.Name) -> $db"
  $sql | docker exec -i inji-postgres psql -v ON_ERROR_STOP=1 -U postgres -d $db
  if ($LASTEXITCODE -eq 0) { Write-Ok $_.Name } else { Write-Fail $_.Name }
}
Restart-Issuer
docker restart verify-service | Out-Null
if (Wait-ForUrl "http://localhost:8095/v1/verify/did.json") { Write-Ok "verify-service back up" } else { Write-Fail "verify-service not answering after restart" }
if (Wait-ForUrl "http://localhost:8091/.well-known/openid-credential-issuer") { Write-Ok "Certify back up" } else { Write-Fail "Certify not answering after restart" }
