param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [switch]$InstallDeps
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'common.ps1')

$caseId = 'case-06-validate-inference'
$log = Start-CaseLog -RepoRoot $RepoRoot -CaseId $caseId
Write-Host "[$caseId] log: $log"

$venvPath = Join-Path $RepoRoot '.venvs\case-06-validate-inference'
$venvPython = Ensure-Venv -VenvPath $venvPath
if ($InstallDeps) {
    Install-Requirements -VenvPython $venvPython -RequirementsFile (Join-Path $RepoRoot 'scripts\requirements\case-06-inference.txt')
}

$env:MPLBACKEND = 'Agg'

Push-Location (Join-Path $RepoRoot 'ModelTraining')
try {
    & $venvPython .\validate_onnx_models.py --report .\Misc\onnx_validation_report.md | Tee-Object -FilePath $log
    if ($LASTEXITCODE -ne 0) {
        throw 'validate_onnx_models.py failed'
    }
}
finally {
    Pop-Location
}

Write-Host "[$caseId] completed"
