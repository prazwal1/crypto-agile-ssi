<#
.SYNOPSIS
  Brings the public tunnel(s) up and wires their URLs into the stack.

.DESCRIPTION
  Two modes, chosen by the presence of tunnel.env (see tunnel.env.example):

  Named (tunnel.env present, decision D-06): one Cloudflare named tunnel on an owned
  domain. Hostnames are fixed, so the issuer DID does not change between runs.

  Quick (no tunnel.env): two Cloudflare quick tunnels.
  Quick tunnels are deleted by Cloudflare after the host sleeps or loses connectivity,
  while the containers keep running. This script:
    1. reads the current tunnel URLs from the container logs;
    2. treats a tunnel as dead if its hostname has no A record on a public resolver
       or cloudflared reports "Tunnel not found", and recreates both tunnels if so;
    3. writes the public URLs to .env (read by docker compose) and wallet.env;
    4. points the issuer DID (did:web) at the Certify tunnel hostname;
    5. restarts Certify and nginx and checks the public endpoints.

  A new Certify hostname changes the issuer DID; credentials issued earlier will no
  longer verify.
#>
. "$PSScriptRoot\common.ps1"

function Get-TunnelUrl($name, $since) {
  $deadline = (Get-Date).AddSeconds(90)
  while ((Get-Date) -lt $deadline) {
    $args2 = @("logs"); if ($since) { $args2 += @("--since", $since) }; $args2 += $name
    $log = (& docker @args2 2>&1) -join "`n"
    $m = [regex]::Matches($log, "https://[a-z0-9-]+\.trycloudflare\.com")
    if ($m.Count -gt 0) { return $m[$m.Count - 1].Value }
    Start-Sleep -Seconds 3
  }
  return $null
}

function Test-PublicDns($url) {
  # A missing name still returns the zone SOA record, so require an A record.
  $h = ([uri]$url).Host
  $a = Resolve-DnsName -Name $h -Server 1.1.1.1 -Type A -DnsOnly -ErrorAction SilentlyContinue | Where-Object { $_.Type -eq "A" }
  return [bool]$a
}

function Test-TunnelDead($name) {
  $recent = (& docker logs --since 3m $name 2>&1) -join "`n"
  return $recent -match "Tunnel not found"
}

function Read-TunnelEnv {
  if (-not (Test-Path .\tunnel.env)) { return $null }
  $t = @{}
  Get-Content .\tunnel.env | Where-Object { $_ -match '^\s*[A-Z_]+=' } | ForEach-Object {
    $k, $v = $_.Split('=', 2); $t[$k.Trim()] = $v.Trim()
  }
  return $t
}

$named = Read-TunnelEnv
Write-Section "Tunnels"
if ($named) {
  foreach ($k in "CF_TUNNEL_TOKEN", "CERTIFY_HOSTNAME", "MIMOTO_HOSTNAME") {
    if (-not $named[$k]) { Write-Fail "tunnel.env is missing $k (see tunnel.env.example)"; exit 1 }
  }
  $certifyUrl = "https://$($named.CERTIFY_HOSTNAME)"
  $mimotoUrl  = "https://$($named.MIMOTO_HOSTNAME)"
  Write-Host "  Mode: named tunnel (fixed hostnames)"
  $previous = Get-EnvValue "PUBLIC_CERTIFY_URL"
  @(
    "COMPOSE_PROFILES=named",
    "CF_TUNNEL_TOKEN=$($named.CF_TUNNEL_TOKEN)",
    "PUBLIC_CERTIFY_URL=$certifyUrl",
    "PUBLIC_CERTIFY_HOST=$($named.CERTIFY_HOSTNAME)",
    "PUBLIC_MIMOTO_URL=$mimotoUrl"
  ) | Set-Content -Path .env -Encoding ascii
  if ($named.VERIFY_HOSTNAME) {
    # Optional third hostname for the verifier (OpenID4VP presentations), mapped to verify-ui:8000
    @("PUBLIC_VERIFY_HOST=$($named.VERIFY_HOSTNAME)", "PUBLIC_VERIFY_URL=https://$($named.VERIFY_HOSTNAME)") | Add-Content -Path .env -Encoding ascii
  }
  # Remove quick-tunnel containers left from the other mode, then start everything.
  docker rm -f tunnel-certify tunnel-mimoto 2>&1 | Out-Null
  docker compose up -d | Out-Null
  $deadline = (Get-Date).AddSeconds(60)
  do { Start-Sleep 3; $reg = (cmd /c "docker logs tunnel-named 2>&1") -match "Registered tunnel connection" } until ($reg -or (Get-Date) -gt $deadline)
  if ($reg) { Write-Ok "tunnel-named registered" } else { Write-Fail "tunnel-named did not register (docker logs tunnel-named; check the token)" }
} else {
  Write-Host "  Mode: quick tunnels (hostnames change on recreate)"
  $prevEnv = if (Test-Path .\.env) { Get-Content .\.env } else { @() }
  if (-not ($prevEnv -contains "COMPOSE_PROFILES=quick")) {
    "COMPOSE_PROFILES=quick" | Set-Content -Path .env -Encoding ascii
    docker rm -f tunnel-named 2>&1 | Out-Null
  }
  # Make sure every service is running (containers stopped by a reboot are started again).
  docker compose up -d | Out-Null
  $certifyUrl = Get-TunnelUrl "tunnel-certify"
  $mimotoUrl  = Get-TunnelUrl "tunnel-mimoto"

  $dead = (-not $certifyUrl) -or (-not $mimotoUrl) -or
          (Test-TunnelDead "tunnel-certify") -or (Test-TunnelDead "tunnel-mimoto") -or
          (-not (Test-PublicDns $certifyUrl)) -or (-not (Test-PublicDns $mimotoUrl))
  if ($dead) {
    Write-Note "Tunnels stale or missing; recreating them (issuer DID will change)"
    $since = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    docker compose up -d --force-recreate tunnel-certify tunnel-mimoto | Out-Null
    $certifyUrl = Get-TunnelUrl "tunnel-certify" $since
    $mimotoUrl  = Get-TunnelUrl "tunnel-mimoto" $since
  }
  if (-not $certifyUrl -or -not $mimotoUrl) { Write-Fail "Could not read tunnel URLs (docker logs tunnel-certify)"; exit 1 }

  $dnsDeadline = (Get-Date).AddSeconds(60)
  while (-not ((Test-PublicDns $certifyUrl) -and (Test-PublicDns $mimotoUrl)) -and (Get-Date) -lt $dnsDeadline) { Start-Sleep 5 }
  Clear-DnsClientCache -ErrorAction SilentlyContinue

  $previous = Get-EnvValue "PUBLIC_CERTIFY_URL"
  @(
    "COMPOSE_PROFILES=quick",
    "PUBLIC_CERTIFY_URL=$certifyUrl",
    "PUBLIC_CERTIFY_HOST=$(([uri]$certifyUrl).Host)",
    "PUBLIC_MIMOTO_URL=$mimotoUrl"
  ) | Set-Content -Path .env -Encoding ascii
}

$certifyHost = ([uri]$certifyUrl).Host
Write-Host "  Certify: $certifyUrl"
Write-Host "  Mimoto : $mimotoUrl"

Write-Section "Wiring public URLs"
"MIMOTO_HOST=$mimotoUrl" | Set-Content -Path wallet.env -Encoding ascii

if ($previous -ne $certifyUrl) {
  docker compose up -d certify | Out-Null   # recreate so Certify reads the new .env
}
docker exec inji-postgres psql -U postgres -d inji_certify -c "UPDATE certify.credential_config SET did_url='did:web:$certifyHost';" | Out-Null
Restart-Issuer

Write-Section "Public endpoints (Certify can take 1 to 3 minutes)"
$checks = [ordered]@{
  "issuer metadata" = "$certifyUrl/v1/certify/.well-known/openid-credential-issuer"
  "AS metadata"     = "$certifyUrl/.well-known/oauth-authorization-server"
  "issuer DID"      = "$certifyUrl/.well-known/did.json"
  "mimoto issuers"  = "$mimotoUrl/v1/mimoto/issuers"
}
$pv = Get-EnvValue "PUBLIC_VERIFY_URL"
if ($pv) { $checks["verifier DID"] = "$pv/v1/verify/did.json"; $checks["verifier UI"] = "$pv/" }
$pending = [System.Collections.ArrayList]@($checks.Keys)
$last = @{}
$deadline = (Get-Date).AddMinutes(5)
while ($pending.Count -gt 0 -and (Get-Date) -lt $deadline) {
  foreach ($n in @($pending)) {
    $code = Get-HttpStatus $checks[$n]
    if ($code -eq "200") { Write-Ok ("{0,-16} {1}" -f $n, $checks[$n]); $pending.Remove($n) | Out-Null }
    else { $last[$n] = $code }
  }
  if ($pending.Count -gt 0) { Start-Sleep -Seconds 10 }
}
foreach ($n in $pending) { Write-Fail ("{0,-16} {1} (HTTP {2})" -f $n, $checks[$n], $last[$n]) }

try {
  $did = Invoke-RestMethod "$certifyUrl/.well-known/did.json" -TimeoutSec 15
  Write-Host "  Issuer DID: $($did.id)"
} catch { }
Write-Host "  wallet.env: MIMOTO_HOST=$mimotoUrl"
