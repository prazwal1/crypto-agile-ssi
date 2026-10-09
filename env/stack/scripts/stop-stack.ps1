<#
.SYNOPSIS
  Stops all containers. Data (database volume, issuer keystore) is kept.
#>
. "$PSScriptRoot\common.ps1"
docker compose stop
