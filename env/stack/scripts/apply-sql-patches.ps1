<#
.SYNOPSIS
  Applies every sql\patches\*.sql file, in name order, to the running inji_certify database.

.DESCRIPTION
  Patches change configuration data only and are written to be safe to re-run.
  Certify and nginx are restarted afterwards so cached configuration is reloaded.
#>
. "$PSScriptRoot\common.ps1"

Write-Section "Applying SQL patches"
Get-ChildItem .\sql\patches\*.sql | Sort-Object Name | ForEach-Object {
  Write-Host "  $($_.Name)"
  Get-Content $_.FullName -Raw | docker exec -i inji-postgres psql -v ON_ERROR_STOP=1 -U postgres -d inji_certify
  if ($LASTEXITCODE -eq 0) { Write-Ok $_.Name } else { Write-Fail $_.Name }
}
Restart-Issuer
if (Wait-ForUrl "http://localhost:8091/.well-known/openid-credential-issuer") { Write-Ok "Certify back up" } else { Write-Fail "Certify not answering after restart" }
