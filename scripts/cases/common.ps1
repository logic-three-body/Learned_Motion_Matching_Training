Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-PythonCommand {
    $python = Get-Command python -ErrorAction SilentlyContinue
    if ($null -ne $python) { return 'python' }

    $py = Get-Command py -ErrorAction SilentlyContinue
    if ($null -ne $py) { return 'py' }

    throw 'Python was not found. Install Python 3.10+ and ensure py or python is in PATH.'
}

function Ensure-Venv {
    param(
        [Parameter(Mandatory = $true)][string]$VenvPath
    )

    $pythonCmd = Get-PythonCommand
    $venvPython = Join-Path $VenvPath 'Scripts\python.exe'
    if (-not (Test-Path $venvPython)) {
        & $pythonCmd -m venv --system-site-packages $VenvPath
        if ($LASTEXITCODE -ne 0) {
            throw "Failed creating virtual environment at $VenvPath"
        }
    }

    if (-not (Test-Path $venvPython)) {
        throw "Failed to create virtual environment at $VenvPath"
    }

    return $venvPython
}

function Install-Requirements {
    param(
        [Parameter(Mandatory = $true)][string]$VenvPython,
        [Parameter(Mandatory = $true)][string]$RequirementsFile
    )

    & $VenvPython -m pip install --upgrade pip
    if ($LASTEXITCODE -ne 0) {
        throw 'pip upgrade failed'
    }
    & $VenvPython -m pip install -r $RequirementsFile
    if ($LASTEXITCODE -ne 0) {
        throw "requirements install failed: $RequirementsFile"
    }
}

function Start-CaseLog {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$CaseId
    )

    $logDir = Join-Path $RepoRoot 'logs'
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir | Out-Null
    }

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $logPath = Join-Path $logDir ("$CaseId-$stamp.log")
    return $logPath
}
