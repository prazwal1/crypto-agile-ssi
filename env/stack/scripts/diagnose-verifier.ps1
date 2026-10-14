<#
.SYNOPSIS
  Collects what is needed to explain a verifier (Inji Verify) failure, into evidence\<date>-verifier-diagnosis\.

.DESCRIPTION
  1. Calls the same status endpoint on three layers: verify-service directly (localhost:8095),
     through the verify-ui nginx (localhost:3000), and through the public tunnel. A layer
     that answers differently from the one below it is where the fault is.
  2. Saves the last 30 minutes of verify-service and verify-ui logs, the nginx config the
     UI container actually uses, and the verifier environment variables (passwords masked).
  Run it right after reproducing the error in the browser.
#>
. "$PSScriptRoot\common.ps1"
$out = Join-Path $RepoRoot ("evidence\{0}-verifier-diagnosis" -f (Get-Date -Format "yyyy-MM-dd"))
New-Item -ItemType Directory -Force -Path $out | Out-Null
$pub = Get-EnvValue "PUBLIC_VERIFY_URL"

Write-Section "Layer test (expected for a made-up id: 404 with NO_AUTH_REQUEST)"
$report = @()
foreach ($base in @("http://localhost:8095", "http://localhost:3000", $pub) | Where-Object { $_ }) {
  foreach ($path in @("/v1/verify/did.json", "/v1/verify/vp-request/diagnose-probe/status")) {
    $body = Join-Path $env:TEMP "diag-body.txt"
    $code = curl.exe -s -o $body -w "%{http_code}" --max-time 20 "$base$path"
    $text = if (Test-Path $body) { (Get-Content $body -Raw) } else { "" }
    if ($text.Length -gt 300) { $text = $text.Substring(0, 300) + "..." }
    $line = "{0}  {1}{2}  {3}" -f $code, $base, $path, ($text -replace "\s+", " ")
    Write-Host "  $line"; $report += $line
  }
}
$report | Out-File (Join-Path $out "layer-test.txt") -Encoding utf8

Write-Section "Logs and configuration"
docker logs --since 30m --timestamps verify-service 2>&1 | ForEach-Object { "$_" } | Out-File (Join-Path $out "verify-service.log") -Encoding utf8
docker logs --since 30m --timestamps verify-ui 2>&1 | ForEach-Object { "$_" } | Out-File (Join-Path $out "verify-ui.log") -Encoding utf8
docker exec verify-ui sh -c "cat /etc/nginx/conf.d/*.conf" 2>&1 | ForEach-Object { "$_" } | Out-File (Join-Path $out "verify-ui-nginx.conf") -Encoding utf8
foreach ($c in "verify-service", "verify-ui") {
  docker inspect $c --format "{{range .Config.Env}}{{println .}}{{end}}" | Where-Object { $_ -match "INJI|VP_|CLIENT|VERIFY|OVP|active_profile" } |
    ForEach-Object { $_ -replace "(PASS[A-Z_]*=).*", '$1***' } | Out-File (Join-Path $out "$c-env.txt") -Encoding utf8
}
$errs = Select-String -Path (Join-Path $out "verify-service.log") -Pattern "ERROR|Exception" | Select-Object -Last 5
if ($errs) { Write-Section "Last errors in verify-service"; $errs | ForEach-Object { $s = $_.Line; Write-Host ("  " + $s.Substring(0, [Math]::Min(250, $s.Length))) } }
Write-Ok "Saved to $out"
