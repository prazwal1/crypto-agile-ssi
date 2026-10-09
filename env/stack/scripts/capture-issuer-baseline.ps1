<#
.SYNOPSIS
  Saves the issuer's public DID document and metadata as dated evidence.

.OUTPUTS
  <repo>\evidence\<yyyy-MM-dd>-issuer-baseline\{did,issuer-meta,as-meta,jwks}.json
  and a summary of algorithms in summary.txt.
#>
. "$PSScriptRoot\common.ps1"

$pub = Get-EnvValue "PUBLIC_CERTIFY_URL"
if (-not $pub) { Write-Fail "No PUBLIC_CERTIFY_URL in .env; run .\stack.ps1 refresh-tunnels"; exit 1 }
$out = Join-Path $RepoRoot ("evidence\{0}-issuer-baseline" -f (Get-Date -Format "yyyy-MM-dd"))
New-Item -ItemType Directory -Force -Path $out | Out-Null

$targets = [ordered]@{
  "did"         = "$pub/.well-known/did.json"
  "issuer-meta" = "$pub/v1/certify/.well-known/openid-credential-issuer"
  "as-meta"     = "$pub/.well-known/oauth-authorization-server"
  "jwks"        = "$pub/.well-known/jwks.json"
}
Write-Section "Capturing issuer baseline from $pub"
foreach ($k in $targets.Keys) {
  try {
    $r = Invoke-WebRequest -Uri $targets[$k] -UseBasicParsing -TimeoutSec 20
    [IO.File]::WriteAllText((Join-Path $out "$k.json"), $r.Content)
    Write-Ok ("{0,-12} {1} bytes" -f $k, $r.Content.Length)
  } catch { Write-Fail ("{0,-12} {1}" -f $k, $_.Exception.Message) }
}

$lines = @("Captured: $(Get-Date -Format s)", "Source:   $pub", "")
try {
  $did = Get-Content (Join-Path $out "did.json") -Raw | ConvertFrom-Json
  $lines += "Issuer DID: $($did.id)"
  foreach ($vm in $did.verificationMethod) { $lines += "  verificationMethod: $($vm.type)" }
  $meta = Get-Content (Join-Path $out "issuer-meta.json") -Raw | ConvertFrom-Json
  foreach ($p in $meta.credential_configurations_supported.PSObject.Properties) {
    $c = $p.Value
    $lines += "Credential $($p.Name): format=$($c.format) signing=$($c.credential_signing_alg_values_supported -join ',') binding=$($c.cryptographic_binding_methods_supported -join ',') proof(jwt)=$($c.proof_types_supported.jwt.proof_signing_alg_values_supported -join ',')"
  }
  $jwks = Get-Content (Join-Path $out "jwks.json") -Raw | ConvertFrom-Json
  foreach ($k in $jwks.keys) { $lines += "  jwk: kty=$($k.kty) crv=$($k.crv)" }
} catch { $lines += "Summary incomplete: $($_.Exception.Message)" }
$lines | Set-Content -Path (Join-Path $out "summary.txt") -Encoding utf8
$lines | Out-Host
