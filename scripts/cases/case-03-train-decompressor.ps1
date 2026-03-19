param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [int]$NIter = 500000,
    [string]$Device = 'cpu',
    [int]$BatchSize = 32,
    [int]$SaveEvery = 1000,
    [switch]$InstallDeps
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'common.ps1')

$caseId = 'case-03-train-decompressor'
$log = Start-CaseLog -RepoRoot $RepoRoot -CaseId $caseId
Write-Host "[$caseId] log: $log"

$venvPath = Join-Path $RepoRoot '.venvs\case-03-train-decompressor'
$venvPython = Ensure-Venv -VenvPath $venvPath
if ($InstallDeps) {
    Install-Requirements -VenvPython $venvPython -RequirementsFile (Join-Path $RepoRoot 'scripts\requirements\case-03.txt')
}

$env:LMM_NITER = "$NIter"
$env:LMM_DEVICE = $Device
$env:LMM_BATCHSIZE = "$BatchSize"
$env:LMM_SAVE_EVERY = "$SaveEvery"
$env:MPLBACKEND = 'Agg'
$env:QT_QPA_PLATFORM = 'offscreen'
$env:KMP_DUPLICATE_LIB_OK = 'TRUE'

Push-Location (Join-Path $RepoRoot 'ModelTraining')
try {
    & $venvPython train_decompressor.py | Tee-Object -FilePath $log
    if ($LASTEXITCODE -ne 0) {
        throw 'train_decompressor.py failed'
    }
}
finally {
    Pop-Location
}

Write-Host "[$caseId] completed"
