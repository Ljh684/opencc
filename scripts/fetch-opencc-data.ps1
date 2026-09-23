<#
.SYNOPSIS
    Refresh the pinned OpenCC dictionaries, configurations and golden corpus.

.DESCRIPTION
    Downloads the OpenCC source archive for a pinned revision and refreshes:

        data/opencc/dictionary/     upstream dictionaries (.txt)
        data/opencc/config/         upstream conversion configurations (.json)
        data/opencc/OPENCC-LICENSE  upstream license text
        data/opencc/REVISION        revision + archive checksum + rationale
        data/opencc/SHA256SUMS      per-file checksum, verified by tools/gen_dict
        test/fixtures/golden/       upstream golden corpus (the acceptance oracle)

    The data is committed to this repository on purpose: the project, its tests and
    its CI all run offline, and the checksums make the snapshot auditable. Run this
    script only when intentionally moving to a new upstream revision.

.EXAMPLE
    pwsh -File scripts/fetch-opencc-data.ps1
    pwsh -File scripts/fetch-opencc-data.ps1 -Revision ver.1.5.0
#>

[CmdletBinding()]
param(
    # Pinned upstream revision: a commit SHA (preferred) or a tag.
    [string]$Revision = "b087c2612ce808f464b0925fc1c497d24971d179",
    [string]$Destination = "data/opencc",
    [string]$Repository = "BYVoid/OpenCC"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$destPath = Join-Path $repoRoot $Destination
$goldenPath = Join-Path $repoRoot "test/fixtures/golden"
$zipPath = Join-Path ([System.IO.Path]::GetTempPath()) "opencc-$([guid]::NewGuid().ToString('N')).zip"
$extractPath = Join-Path ([System.IO.Path]::GetTempPath()) "opencc-$([guid]::NewGuid().ToString('N'))"

$url = "https://codeload.github.com/$Repository/zip/$Revision"
Write-Host "Downloading $url"
Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing

$hash = (Get-FileHash -Path $zipPath -Algorithm SHA256).Hash
Write-Host "Archive SHA-256: $hash"

Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
$root = Get-ChildItem -Path $extractPath -Directory | Select-Object -First 1
if (-not $root) { throw "Extracted archive did not contain a root directory." }

New-Item -ItemType Directory -Force -Path (Join-Path $destPath "dictionary/staging") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $destPath "config") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $goldenPath "input") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $goldenPath "output") | Out-Null

# Dictionaries: text only. The upstream C++ test files and BUILD.bazel in the same
# directory are not part of the data snapshot.
Get-ChildItem -Path (Join-Path $root.FullName "data/dictionary") -Recurse -File -Filter *.txt | ForEach-Object {
    $rel = $_.FullName.Substring((Join-Path $root.FullName "data/dictionary").Length + 1)
    $target = Join-Path (Join-Path $destPath "dictionary") $rel
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
    Copy-Item -LiteralPath $_.FullName -Destination $target -Force
}

Copy-Item -Path (Join-Path $root.FullName "data/config/*.json") -Destination (Join-Path $destPath "config") -Force
Copy-Item -Path (Join-Path $root.FullName "LICENSE") -Destination (Join-Path $destPath "OPENCC-LICENSE") -Force

Copy-Item -Path (Join-Path $root.FullName "test/golden/input/*") -Destination (Join-Path $goldenPath "input") -Force
Copy-Item -Path (Join-Path $root.FullName "test/golden/output/*") -Destination (Join-Path $goldenPath "output") -Force

# Checksums cover the data snapshot only: REVISION and SHA256SUMS describe it, so
# they are intentionally not part of it.
$sumPath = Join-Path $destPath "SHA256SUMS"
$lines = Get-ChildItem -Path $destPath -Recurse -File |
    Where-Object { $_.Name -notin @("SHA256SUMS", "REVISION") } |
    Sort-Object { $_.FullName } |
    ForEach-Object {
        $rel = $_.FullName.Substring($destPath.Length + 1).Replace("\", "/")
        "{0}  {1}" -f (Get-FileHash -Path $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant(), $rel
    }
$lines | Set-Content -Path $sumPath -Encoding utf8

@(
    "Upstream:  https://github.com/$Repository",
    "Revision:  $Revision",
    "Archive:   $url",
    "Archive-SHA256: $hash",
    "Fetched:   $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))",
    "License:   Apache-2.0 (see OPENCC-LICENSE in this directory)"
) | Set-Content -Path (Join-Path $destPath "REVISION") -Encoding utf8

Remove-Item -Recurse -Force $extractPath
Remove-Item -Force $zipPath

Write-Host "OpenCC data ready at $destPath"
Write-Host "Golden corpus refreshed at $goldenPath"
Write-Host "Next: moon run tools/gen_dict -- --input $Destination --out src/data"
