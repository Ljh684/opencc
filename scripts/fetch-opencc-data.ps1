<#
.SYNOPSIS
    Fetch the pinned OpenCC dictionaries and golden test corpus into vendor/.

.DESCRIPTION
    Downloads the OpenCC source archive for a pinned revision, extracts only the
    data/ and test/golden/ directories, records the revision and archive checksum
    in vendor/OPENCC-REVISION.txt, and leaves vendor/ untouched otherwise.
    vendor/ is git-ignored: it is an input for tools/gen_dict, not a source artifact.

.EXAMPLE
    pwsh -File scripts/fetch-opencc-data.ps1
    pwsh -File scripts/fetch-opencc-data.ps1 -Revision master
#>

[CmdletBinding()]
param(
    # Pinned upstream revision. Use a tag (e.g. ver.1.1.9) or a commit SHA.
    [string]$Revision = "master",
    [string]$Destination = "vendor/opencc",
    [string]$Repository = "BYVoid/OpenCC"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$destPath = Join-Path $repoRoot $Destination
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

if (Test-Path $destPath) { Remove-Item -Recurse -Force $destPath }
New-Item -ItemType Directory -Path $destPath -Force | Out-Null

Copy-Item -Path (Join-Path $root.FullName "data") -Destination $destPath -Recurse
New-Item -ItemType Directory -Path (Join-Path $destPath "test") -Force | Out-Null
Copy-Item -Path (Join-Path $root.FullName "test/golden") -Destination (Join-Path $destPath "test") -Recurse
Copy-Item -Path (Join-Path $root.FullName "LICENSE") -Destination (Join-Path $destPath "OPENCC-LICENSE") -Force

@(
    "repository: https://github.com/$Repository",
    "requested revision: $Revision",
    "archive sha256: $hash",
    "fetched at: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))"
) | Set-Content -Path (Join-Path $destPath "OPENCC-REVISION.txt") -Encoding utf8

Remove-Item -Recurse -Force $extractPath
Remove-Item -Force $zipPath

Write-Host "OpenCC data ready at $destPath"
Write-Host "Next: moon run tools/gen_dict -- --input $Destination --out src/data"
