<#
.SYNOPSIS
  Pulls images, starts all containers, publishes the tunnels and runs the health checks.
#>
. "$PSScriptRoot\common.ps1"

docker info *> $null
if ($LASTEXITCODE -ne 0) { Write-Fail "Docker is not running. Start Docker Desktop first."; exit 1 }

Write-Section "Pulling images"
docker compose pull
Write-Section "Starting containers"
docker compose up -d
if ($LASTEXITCODE -ne 0) { Write-Fail "docker compose up failed"; exit 1 }

Write-Section "Waiting for Certify and Mimoto"
if (Wait-ForUrl "http://localhost:8090/v1/certify/actuator/health") { Write-Ok "Certify" } else { Write-Fail "Certify did not become healthy" }
if (Wait-ForUrl "http://localhost:8099/v1/mimoto/issuers") { Write-Ok "Mimoto" } else { Write-Fail "Mimoto not answering" }

& "$PSScriptRoot\refresh-tunnels.ps1"
& "$PSScriptRoot\check-health.ps1"
