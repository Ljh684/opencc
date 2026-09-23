<#
.SYNOPSIS
    Configure this repository's git identity and create the first commit.

.DESCRIPTION
    Sets repository-local user.name/user.email (never global), ensures the
    default branch is `main`, stages everything, and makes the initial commit.
    Run it once after installing Git:

        winget install --id Git.Git -e
        pwsh -File scripts/setup-git.ps1

    Then create the GitHub repository and push:

        git remote add origin https://github.com/Ljh684/opencc.mbt.git
        git push -u origin main
#>

[CmdletBinding()]
param(
    [string]$UserName = "Ljh684",
    [string]$UserEmail = "2662386825@qq.com",
    [string]$Branch = "main",
    [string]$Message = "chore: initial repository skeleton for opencc.mbt"
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "git was not found on PATH. Install it first: winget install --id Git.Git -e"
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

if (-not (Test-Path (Join-Path $repoRoot ".git"))) {
    git init --initial-branch=$Branch
}

git config user.name $UserName
git config user.email $UserEmail

Write-Host "Identity for this repository:"
git config --get user.name
git config --get user.email

git add --all

$staged = git diff --cached --name-only
if (-not $staged) {
    Write-Host "Nothing staged; working tree already clean."
    exit 0
}

git commit -m $Message
git log --oneline -1
