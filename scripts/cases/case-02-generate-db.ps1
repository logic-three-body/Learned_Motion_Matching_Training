param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$BinDir = '',
    [switch]$InstallDeps
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'common.ps1')

$caseId = 'case-02-generate-db'
$log = Start-CaseLog -RepoRoot $RepoRoot -CaseId $caseId
Write-Host "[$caseId] log: $log"

if ([string]::IsNullOrWhiteSpace($BinDir)) {
    $BinDir = Join-Path $RepoRoot 'Animations\LAFAN1BIN'
}

$required = @(
    'pushAndStumble1_subject5.bin',
    'run1_subject5.bin',
    'walk1_subject5.bin',
    'boneParentInfo.bin'
)

$missing = @($required | Where-Object { -not (Test-Path (Join-Path $BinDir $_)) })
if ($missing.Count -gt 0) {
    $fallback = Join-Path $RepoRoot 'ModelTraining\\Data'
    $fallbackMissing = @($required | Where-Object { -not (Test-Path (Join-Path $fallback $_)) })
    if ($fallbackMissing.Count -eq 0) {
        $BinDir = $fallback
        Write-Host "[$caseId] using fallback binary source: $BinDir"
    }
}

$venvPath = Join-Path $RepoRoot '.venvs\case-02-generate-db'
$venvPython = Ensure-Venv -VenvPath $venvPath
if ($InstallDeps) {
    Install-Requirements -VenvPython $venvPython -RequirementsFile (Join-Path $RepoRoot 'scripts\requirements\case-02.txt')
}

$env:LMM_BIN_DIR = $BinDir
$env:MPLBACKEND = 'Agg'

Push-Location (Join-Path $RepoRoot 'ModelTraining')
try {
    & $venvPython generate_database.py | Tee-Object -FilePath $log
    if ($LASTEXITCODE -ne 0) {
        throw 'generate_database.py failed'
    }
}
finally {
    Pop-Location
}

Write-Host "[$caseId] completed"
