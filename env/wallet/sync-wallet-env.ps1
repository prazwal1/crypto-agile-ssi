<#
.SYNOPSIS
  Copies MIMOTO_HOST from ..\stack\wallet.env (written by refresh-tunnels) into the wallet's .env.
#>
param(
  [string]$WalletDir = (Join-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot))) "inji-wallet"),
  [string]$StackDir = (Join-Path (Split-Path -Parent $PSScriptRoot) "stack")
)
$src = Join-Path $StackDir "wallet.env"
$dst = Join-Path $WalletDir ".env"
if (-not (Test-Path $src)) { Write-Host "  WARN  $src not found. Run ..\stack\stack.ps1 refresh-tunnels first." -ForegroundColor Yellow; return }
$mimoto = (Get-Content $src | Where-Object { $_ -like "MIMOTO_HOST=*" } | Select-Object -First 1)
$lines = Get-Content $dst
$lines = $lines | ForEach-Object {
  if ($_ -like "MIMOTO_HOST=*") { $mimoto }
  else { $_ }
}
$lines | Set-Content $dst -Encoding ascii
Write-Host "  OK    wallet .env -> $mimoto" -ForegroundColor Green
