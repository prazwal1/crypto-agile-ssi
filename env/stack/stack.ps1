<#
.SYNOPSIS
  Single entry point for operating the local Inji stack.

.DESCRIPTION
  Runs one of the scripts in .\scripts and records the full console output in
  logs\<timestamp>-<command>.log so every run is traceable.

.EXAMPLE
  .\stack.ps1 start            # pull images, start containers, publish tunnels, check health
  .\stack.ps1 refresh-tunnels  # replace dead quick tunnels, update issuer URL and DID
  .\stack.ps1 check            # local and public health checks
  .\stack.ps1 restart-issuer   # restart Certify and nginx after a config change
  .\stack.ps1 apply-patches    # apply sql\patches\*.sql to the running database
  .\stack.ps1 issue-offer      # create a pre-authorized test credential offer (QR in offer.html)
  .\stack.ps1 capture-baseline # save issuer DID and metadata to evidence\<date>-issuer-baseline
  .\stack.ps1 reset-keys       # regenerate issuer keys (invalidates issued credentials)
  .\stack.ps1 diagnose-verifier # layer test, logs and config of Inji Verify into evidence\
  .\stack.ps1 stop             # stop containers, keep data
#>
param(
  [Parameter(Position = 0)]
  [ValidateSet("start", "refresh-tunnels", "check", "restart-issuer", "apply-patches", "issue-offer", "capture-baseline", "reset-keys", "diagnose-verifier", "stop")]
  [string]$Command = "check"
)

$map = @{
  "start"            = "start-stack.ps1"
  "refresh-tunnels"  = "refresh-tunnels.ps1"
  "check"            = "check-health.ps1"
  "restart-issuer"   = "restart-issuer.ps1"
  "apply-patches"    = "apply-sql-patches.ps1"
  "issue-offer"      = "issue-test-offer.ps1"
  "capture-baseline" = "capture-issuer-baseline.ps1"
  "reset-keys"       = "reset-issuer-keys.ps1"
  "diagnose-verifier" = "diagnose-verifier.ps1"
  "stop"             = "stop-stack.ps1"
}

Set-Location $PSScriptRoot
New-Item -ItemType Directory -Force -Path .\logs | Out-Null
$log = Join-Path $PSScriptRoot ("logs\{0}-{1}.log" -f (Get-Date -Format "yyyyMMdd-HHmmss"), $Command)
Start-Transcript -Path $log -Force | Out-Null
try {
  & (Join-Path $PSScriptRoot "scripts\$($map[$Command])")
} finally {
  Stop-Transcript | Out-Null
  Write-Host "Log: $log"
}
