<#
.SYNOPSIS
  Exports every OpenID4VP submission stored by Inji Verify, with face images removed,
  into evidence\<date>-presentation-export\.

.DESCRIPTION
  verify.vp_submission keeps the full VP token and presentation submission. The wallet log
  truncates them, so this is the only complete record of the presentation proof.
  Any data:image value (the holder photo) is replaced with a placeholder before the file is written.
#>
. "$PSScriptRoot\common.ps1"
$out = Join-Path $RepoRoot ("evidence\{0}-presentation-export" -f (Get-Date -Format "yyyy-MM-dd"))
New-Item -ItemType Directory -Force -Path $out | Out-Null

# The table has no creation time; rows are matched to runs by request_id (state) in verify-service.log.
$sql = "SELECT json_agg(t) FROM (SELECT request_id, error, error_description, presentation_submission, vp_token FROM verify.vp_submission) t;"
$raw = docker exec inji-postgres psql -U postgres -d inji_verify -t -A -c $sql
if ($LASTEXITCODE -ne 0 -or -not $raw) { Write-Fail "Query failed"; exit 1 }
$raw = ($raw -join "`n")
$clean = [regex]::Replace($raw, 'data:image/[a-zA-Z]+;base64,[A-Za-z0-9+/=\\]+', '<face image redacted>')
$n = ([regex]::Matches($raw, 'data:image/')).Count
$clean | Set-Content -Path (Join-Path $out "vp_submission.json") -Encoding utf8
$rows = ([regex]::Matches($raw, '"request_id"')).Count
Write-Ok ("{0} submissions exported, {1} face images redacted" -f $rows, $n)
Write-Host "  $out\vp_submission.json"
