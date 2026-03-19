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

$caseId = 'case-05-train-stepper'
$log = Start-CaseLog -RepoRoot $RepoRoot -CaseId $caseId
Write-Host "[$caseId] log: $log"

$venvPath = Join-Path $RepoRoot '.venvs\case-05-train-stepper'
$venvPython = Ensure-Venv -VenvPath $venvPath
if ($InstallDeps) {
    Install-Requirements -VenvPython $venvPython -RequirementsFile (Join-Path $RepoRoot 'scripts\requirements\case-05.txt')
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
    & $venvPython train_stepper.py | Tee-Object -FilePath $log
    if ($LASTEXITCODE -ne 0) {
        throw 'train_stepper.py failed'
    }
}
finally {
    Pop-Location
}

Write-Host "[$caseId] completed"
