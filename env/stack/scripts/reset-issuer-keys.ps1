<#
.SYNOPSIS
  Deletes Certify's key records and keystore so it generates new issuer keys on start.

.DESCRIPTION
  Use only when Certify fails with "KER-KMA-004 No such alias" (the database lists keys
  whose keystore file is missing). Every credential issued before the reset stops verifying.
#>
. "$PSScriptRoot\common.ps1"

Write-Note "This invalidates all previously issued credentials."
docker compose stop certify | Out-Null
docker exec inji-postgres psql -U postgres -d inji_certify -c "DELETE FROM certify.key_store; DELETE FROM certify.key_alias; DELETE FROM certify.ca_cert_store;"
Remove-Item -Force -ErrorAction SilentlyContinue .\data\CERTIFY_PKCS12\local.p12
docker compose up -d --force-recreate certify | Out-Null
docker restart certify-nginx | Out-Null

if (Wait-ForUrl "http://localhost:8090/v1/certify/actuator/health") { Write-Ok "Certify started" } else { Write-Fail "Certify did not start" }
if (Test-Path .\data\CERTIFY_PKCS12\local.p12) { Write-Ok "Keystore persisted at data\CERTIFY_PKCS12\local.p12" }
else { Write-Fail "Keystore not on the host; keys would be lost on the next recreate" }
