<#
.SYNOPSIS
  Registers (or updates) a credential type in Certify through its own API, from a JSON file in
  config\credential-configs\. Default: FarmerCredentialSdJwt (D-02).

.DESCRIPTION
  POST /v1/certify/credential-configurations on localhost:8090 (the public hostname blocks this
  endpoint, see nginx/certify.conf). If the id already exists, PUT replaces it.
  The vcTemplate object in the file is serialised and base64-encoded, as Certify stores it.
  The keys _comment are dropped. Certify and nginx are restarted afterwards so the metadata
  and config caches are rebuilt.
#>
param([string]$File = "config\credential-configs\FarmerCredentialSdJwt.json")
. "$PSScriptRoot\common.ps1"

$cfg = Get-Content $File -Raw | ConvertFrom-Json
$cfg.PSObject.Properties.Remove("_comment")
$tpl = $cfg.vcTemplate | ConvertTo-Json -Depth 10 -Compress
$cfg.vcTemplate = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($tpl))
$body = $cfg | ConvertTo-Json -Depth 10
$id = $cfg.credentialConfigKeyId
$base = "http://localhost:8090/v1/certify/credential-configurations"

Write-Section "Credential configuration $id"
$exists = $false
try { Invoke-RestMethod -Uri "$base/$id" -Method Get | Out-Null; $exists = $true } catch { }
try {
  if ($exists) {
    $r = Invoke-RestMethod -Uri "$base/$id" -Method Put -ContentType "application/json" -Body $body
    Write-Ok "Updated: $($r | ConvertTo-Json -Compress)"
  } else {
    $r = Invoke-RestMethod -Uri $base -Method Post -ContentType "application/json" -Body $body
    Write-Ok "Created: $($r | ConvertTo-Json -Compress)"
  }
} catch {
  Write-Fail "Request failed: $($_.Exception.Message)"
  if ($_.ErrorDetails) { $_.ErrorDetails.Message | Out-Host }
  exit 1
}
Restart-Issuer
if (Wait-ForUrl "http://localhost:8091/.well-known/openid-credential-issuer") { Write-Ok "Certify back up" } else { Write-Fail "Certify not answering after restart" }
$meta = Invoke-RestMethod "http://localhost:8091/.well-known/openid-credential-issuer"
$c = $meta.credential_configurations_supported.$id
if ($c) { Write-Ok ("Published: format {0}, vct {1}, signing {2}, proofs {3}" -f $c.format, $c.vct, ($c.credential_signing_alg_values_supported -join ","), ($c.proof_types_supported.jwt.proof_signing_alg_values_supported -join ",")) }
else { Write-Fail "$id not in issuer metadata" }
