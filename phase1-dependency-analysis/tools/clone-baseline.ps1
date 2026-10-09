# Re-creates the pinned Phase 1 baseline on Windows.
# Usage (from the phase1 folder):  powershell -ExecutionPolicy Bypass -File tools\clone-baseline.ps1
# Clones each repo at its pinned tag and fails loudly if the commit differs from manifest.tsv.
$ErrorActionPreference = "Stop"
git config --global core.longpaths true
$root = Split-Path -Parent $PSScriptRoot
New-Item -ItemType Directory -Force -Path "$root\repos" | Out-Null
Get-Content "$root\manifest.tsv" | ForEach-Object {
    $f = $_ -split "`t"
    $repo, $tag, $sha = $f[0], $f[1], $f[2]
    $dest = "$root\repos\$repo"
    if (-not (Test-Path $dest)) {
        git clone -q --depth 1 --branch $tag "https://github.com/mosip/$repo" $dest
    }
    $actual = (git -C $dest rev-parse HEAD).Trim()
    if ($actual -ne $sha) { throw "$repo at $tag is $actual, manifest says $sha" }
    Write-Host ("OK  {0,-16} {1,-8} {2}" -f $repo, $tag, $sha.Substring(0, 12))
}
