param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [switch]$InstallDeps,
    [switch]$Smoke,
    [switch]$SkipCase01,
    [switch]$SkipInference
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$cases = Join-Path $RepoRoot 'scripts\cases'

$niter03 = if ($Smoke) { 300 } else { 500000 }
$niter45 = if ($Smoke) { 800 } else { 500000 }
$saveEvery = if ($Smoke) { -1 } else { 1000 }

if (-not $SkipCase01) {
    & (Join-Path $cases 'case-01-dataprocess.ps1') -RepoRoot $RepoRoot
}

& (Join-Path $cases 'case-02-generate-db.ps1') -RepoRoot $RepoRoot -InstallDeps:$InstallDeps

# case-03 is dependency root for latent.bin, run first on cuda:1
& (Join-Path $cases 'case-03-train-decompressor.ps1') -RepoRoot $RepoRoot -NIter $niter03 -Device 'cuda:1' -BatchSize 256 -SaveEvery $saveEvery -InstallDeps:$InstallDeps

# case-04 and case-05 can run in parallel on separate GPUs
$j4 = Start-Job -ScriptBlock {
    param($repo, $script, $niter, $save, $install)
    & $script -RepoRoot $repo -NIter $niter -Device 'cuda:0' -BatchSize 32 -SaveEvery $save -InstallDeps:$install
} -ArgumentList $RepoRoot, (Join-Path $cases 'case-04-train-projector.ps1'), $niter45, $saveEvery, $InstallDeps

$j5 = Start-Job -ScriptBlock {
    param($repo, $script, $niter, $save, $install)
    & $script -RepoRoot $repo -NIter $niter -Device 'cuda:1' -BatchSize 64 -SaveEvery $save -InstallDeps:$install
} -ArgumentList $RepoRoot, (Join-Path $cases 'case-05-train-stepper.ps1'), $niter45, $saveEvery, $InstallDeps

Wait-Job $j4, $j5 | Out-Null
Receive-Job $j4
Receive-Job $j5
if (($j4.State -ne 'Completed') -or ($j5.State -ne 'Completed')) {
    throw 'Best-HW run failed in case-04 or case-05.'
}
Remove-Job $j4, $j5

if (-not $SkipInference) {
    & (Join-Path $cases 'case-06-validate-inference.ps1') -RepoRoot $RepoRoot -InstallDeps:$InstallDeps
}

Write-Host 'Best hardware training pipeline completed.'
