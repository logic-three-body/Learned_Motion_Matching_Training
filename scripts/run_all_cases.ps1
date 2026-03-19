param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [switch]$InstallDeps,
    [switch]$SkipCase01,
    [switch]$Smoke,
    [switch]$SkipInference
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$casesRoot = Join-Path $RepoRoot 'scripts\cases'

$niter = if ($Smoke) { 20 } else { 500000 }

if (-not $SkipCase01) {
    & (Join-Path $casesRoot 'case-01-dataprocess.ps1') -RepoRoot $RepoRoot
}

& (Join-Path $casesRoot 'case-02-generate-db.ps1') -RepoRoot $RepoRoot -InstallDeps:$InstallDeps
& (Join-Path $casesRoot 'case-03-train-decompressor.ps1') -RepoRoot $RepoRoot -NIter $niter -InstallDeps:$InstallDeps

& (Join-Path $casesRoot 'case-04-train-projector.ps1') -RepoRoot $RepoRoot -NIter $niter -InstallDeps:$InstallDeps
& (Join-Path $casesRoot 'case-05-train-stepper.ps1') -RepoRoot $RepoRoot -NIter $niter -InstallDeps:$InstallDeps

if (-not $SkipInference) {
    & (Join-Path $casesRoot 'case-06-validate-inference.ps1') -RepoRoot $RepoRoot -InstallDeps:$InstallDeps
}

Write-Host 'All requested cases completed.'
