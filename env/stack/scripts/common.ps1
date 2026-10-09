<#
.SYNOPSIS
  Shared settings and helpers, dot-sourced by every script in this folder.
#>
$ErrorActionPreference = "Continue"
# Windows PowerShell 5.1 defaults to TLS 1.0; Cloudflare endpoints require TLS 1.2+.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$StackDir = Split-Path -Parent $PSScriptRoot
$RepoRoot = Split-Path -Parent (Split-Path -Parent $StackDir)
Set-Location $StackDir

function Write-Section($text) { Write-Host "`n== $text" -ForegroundColor Cyan }
function Write-Ok($text)      { Write-Host "  OK    $text" -ForegroundColor Green }
function Write-Fail($text)    { Write-Host "  FAIL  $text" -ForegroundColor Red }
function Write-Note($text)    { Write-Host "  NOTE  $text" -ForegroundColor Yellow }

function Get-EnvValue($name) {
  if (-not (Test-Path .\.env)) { return $null }
  $line = Get-Content .\.env | Where-Object { $_ -like "$name=*" } | Select-Object -First 1
  if ($line) { return $line.Substring($name.Length + 1) }
  return $null
}

function Get-HttpStatus($url) {
  return (curl.exe -s -o NUL -w "%{http_code}" --max-time 15 $url)
}

function Restart-Issuer {
  # nginx resolves the certify container address once at startup, so it must be
  # restarted whenever Certify is restarted or recreated (otherwise: 502).
  docker restart certify | Out-Null
  docker restart certify-nginx | Out-Null
}

function Wait-ForUrl($url, [int]$timeoutSec = 180) {
  $deadline = (Get-Date).AddSeconds($timeoutSec)
  do {
    if ((Get-HttpStatus $url) -eq "200") { return $true }
    Start-Sleep -Seconds 5
  } while ((Get-Date) -lt $deadline)
  return $false
}
