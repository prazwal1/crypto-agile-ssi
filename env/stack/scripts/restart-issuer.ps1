<#
.SYNOPSIS
  Restarts Certify and its nginx front end, then waits until the issuer metadata answers.

.DESCRIPTION
  Use after changing files in config\ (they are bind-mounted and read at start-up).
#>
. "$PSScriptRoot\common.ps1"

Write-Section "Restarting Certify and nginx"
Restart-Issuer
if (Wait-ForUrl "http://localhost:8091/.well-known/openid-credential-issuer") { Write-Ok "Certify back up" } else { Write-Fail "Certify not answering after restart" }
