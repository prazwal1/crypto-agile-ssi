<#
.SYNOPSIS
  Creates a pre-authorized FarmerCredential offer (OpenID4VCI) and renders it as a QR code.

.PARAMETER Id
  Row id in config\farmer_identity_data.csv whose claims go into the credential.

.PARAMETER FaceFile
  Optional photo (jpg or png) that replaces the row's face claim. Needed for presentations:
  Inji Wallet forces "Share with selfie" for any credential with a face, and the sample rows
  carry a 28x5 placeholder that crashes its face matcher (minimum 32x32). The photo is
  resized to at most 400 px, sent only to the local Certify, and never written to the repo.
  Keep it outside the repo, e.g. F:\thesis\private\face.jpg.

.OUTPUTS
  offer.html (opened in the default browser).
#>
param(
  [string]$Id = "2154189532",
  [string]$TxCode = "",
  [int]$ExpiresIn = 600,
  [string]$FaceFile = ""
)
. "$PSScriptRoot\common.ps1"

$row = Import-Csv .\config\farmer_identity_data.csv | Where-Object { $_.id -eq $Id } | Select-Object -First 1
if (-not $row) { Write-Fail "No row with id $Id in config\farmer_identity_data.csv"; exit 1 }

$claims = [ordered]@{}
foreach ($p in $row.PSObject.Properties) { if ($p.Name -ne "id") { $claims[$p.Name] = $p.Value } }

if ($FaceFile) {
  if (-not (Test-Path $FaceFile)) { Write-Fail "Face file not found: $FaceFile"; exit 1 }
  Add-Type -AssemblyName System.Drawing
  $img = [System.Drawing.Image]::FromFile((Resolve-Path $FaceFile))
  $scale = [Math]::Min(1.0, 400.0 / [Math]::Max($img.Width, $img.Height))
  $w = [int]($img.Width * $scale); $h = [int]($img.Height * $scale)
  $bmp = New-Object System.Drawing.Bitmap $w, $h
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.DrawImage($img, 0, 0, $w, $h)
  $ms = New-Object System.IO.MemoryStream
  $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Jpeg)
  $g.Dispose(); $bmp.Dispose(); $img.Dispose()
  $claims["face"] = "data:image/jpeg;base64," + [Convert]::ToBase64String($ms.ToArray())
  Write-Ok ("Face claim from {0} ({1}x{2}, {3} KB)" -f (Split-Path $FaceFile -Leaf), $w, $h, [int]($ms.Length / 1024))
}

$body = [ordered]@{ credential_configuration_id = "FarmerCredential"; claims = $claims; expires_in = $ExpiresIn }
if ($TxCode) { $body.tx_code = $TxCode }

Write-Section "Requesting credential offer"
try {
  $resp = Invoke-RestMethod -Method Post -Uri "http://localhost:8090/v1/certify/pre-authorized-data" `
    -ContentType "application/json" -Body ($body | ConvertTo-Json -Depth 5)
} catch {
  Write-Fail "Request failed: $($_.Exception.Message)"
  if ($_.ErrorDetails) { $_.ErrorDetails.Message | Out-Host }
  exit 1
}
$offer = $resp.credential_offer_uri
if (-not $offer) { $offer = $resp.response.credential_offer_uri }
if (-not $offer) { Write-Fail "No offer returned"; $resp | ConvertTo-Json -Depth 6 | Out-Host; exit 1 }
Write-Ok "Offer created"
Write-Host "  $offer"

$enc = [System.Net.WebUtility]::HtmlEncode($offer)
$js  = $offer.Replace('\', '\\').Replace("'", "\'")
$html = @"
<!doctype html><html><head><meta charset="utf-8"><title>Credential offer</title>
<script src="https://cdnjs.cloudflare.com/ajax/libs/qrcodejs/1.0.0/qrcode.min.js"></script>
<style>body{font-family:sans-serif;margin:32px;background:#fff;color:#111}#qr{margin:24px 0}code{word-break:break-all;font-size:12px}</style>
</head><body>
<h2>FarmerCredential offer for $Id</h2>
<p>Scan with Inji Wallet. Expires in $ExpiresIn seconds.$(if ($TxCode) { " Transaction code: <b>$TxCode</b>" })</p>
<div id="qr"></div>
<code>$enc</code>
<script>new QRCode(document.getElementById('qr'),{text:'$js',width:360,height:360,correctLevel:QRCode.CorrectLevel.L});</script>
</body></html>
"@
$html | Set-Content -Path .\offer.html -Encoding utf8
Start-Process .\offer.html
