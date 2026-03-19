param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$Configuration = 'Debug',
    [string]$Platform = 'x64',
    [string]$FbxSdkRoot = $env:FBXSDK_ROOT
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'common.ps1')

$caseId = 'case-01-dataprocess'
$log = Start-CaseLog -RepoRoot $RepoRoot -CaseId $caseId
Write-Host "[$caseId] log: $log"

$venvPath = Join-Path $RepoRoot '.venvs\case-01-dataprocess'
$venvPython = Ensure-Venv -VenvPath $venvPath

if ([string]::IsNullOrWhiteSpace($FbxSdkRoot)) {
    $autoRoots = @(
        'C:\Program Files\Autodesk\FBX\FBX SDK\2020.3.2',
        'C:\Program Files\Autodesk\FBX\FBX SDK\2020.2.1',
        'C:\Program Files\Side Effects Software\Houdini 21.0.512',
        'C:\Program Files\Side Effects Software\Houdini 20.5.278'
    )
    $FbxSdkRoot = $autoRoots | Where-Object { Test-Path $_ } | Select-Object -First 1
}
if ([string]::IsNullOrWhiteSpace($FbxSdkRoot) -or -not (Test-Path $FbxSdkRoot)) {
    throw 'FBXSDK_ROOT is not set or invalid, and no supported Autodesk/Houdini FBX SDK path was auto-detected.'
}

$msbuildPath = (Get-Command msbuild -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue)
if (-not $msbuildPath) {
    $msbuildCandidates = @(
        'C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe',
        'C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\amd64\MSBuild.exe',
        'C:\Program Files\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe',
        'C:\Program Files\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\amd64\MSBuild.exe'
    )
    $msbuildPath = $msbuildCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
}
if (-not $msbuildPath) {
    throw 'MSBuild was not found. Install Visual Studio Build Tools with C++ workload.'
}

$fbxIncludeDir = Join-Path $FbxSdkRoot 'include'
$fbxLibDir = Join-Path $FbxSdkRoot 'lib\vs2022\x64\debug'
if (-not (Test-Path $fbxIncludeDir)) {
    $houdiniInclude = Join-Path $FbxSdkRoot 'toolkit\include\fbx'
    if (Test-Path $houdiniInclude) {
        $fbxIncludeDir = $houdiniInclude
    }
}
if (-not (Test-Path $fbxLibDir)) {
    $houdiniLib = Join-Path $FbxSdkRoot 'custom\houdini\dsolib'
    if (Test-Path $houdiniLib) {
        $fbxLibDir = $houdiniLib
    }
}
if (-not (Test-Path (Join-Path $fbxIncludeDir 'fbxsdk.h'))) {
    throw "Could not find fbxsdk.h in include path: $fbxIncludeDir"
}
if (-not (Test-Path (Join-Path $fbxLibDir 'libfbxsdk.lib'))) {
    throw "Could not find libfbxsdk.lib in library path: $fbxLibDir"
}

$dpRoot = Join-Path $RepoRoot 'DataProcessing'
$solution = Join-Path $dpRoot 'FbxToBinConverter.sln'

Push-Location $dpRoot
try {
    $env:FBXSDK_ROOT = $FbxSdkRoot
    $env:FBXSDK_INCLUDE_DIR = $fbxIncludeDir
    $env:FBXSDK_LIB_DIR = $fbxLibDir
    & $msbuildPath $solution /t:Build /p:Configuration=$Configuration /p:Platform=$Platform | Tee-Object -FilePath $log
    if ($LASTEXITCODE -ne 0) {
        throw 'msbuild failed for DataProcessing solution'
    }
}
finally {
    Pop-Location
}

$exeCandidates = @(
    (Join-Path $dpRoot "x64\$Configuration\ThesisStuff.exe"),
    (Join-Path $dpRoot "$Configuration\ThesisStuff.exe"),
    (Join-Path $dpRoot "x64\$Configuration\FbxToBinConverter.exe"),
    (Join-Path $dpRoot "$Configuration\FbxToBinConverter.exe")
)
$exePath = $exeCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $exePath) {
    throw 'Could not locate built executable (ThesisStuff.exe or FbxToBinConverter.exe).'
}

$dll = Get-ChildItem -Path $FbxSdkRoot -Filter libfbxsdk.dll -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if ($null -eq $dll) {
    throw 'libfbxsdk.dll was not found under FBXSDK_ROOT.'
}
Copy-Item $dll.FullName -Destination (Split-Path $exePath -Parent) -Force

$bvhDir = Join-Path $RepoRoot 'Animations\LAFAN1BVH\'
$fbxDir = Join-Path $RepoRoot 'Animations\LAFAN1FBX\'
$binDir = Join-Path $RepoRoot 'Animations\LAFAN1BIN\'

if (-not (Test-Path $fbxDir)) { New-Item -ItemType Directory -Path $fbxDir | Out-Null }
if (-not (Test-Path $binDir)) { New-Item -ItemType Directory -Path $binDir | Out-Null }

Push-Location (Split-Path $exePath -Parent)
try {
    & $exePath $fbxDir $binDir $bvhDir | Tee-Object -FilePath $log -Append
    if ($LASTEXITCODE -ne 0) {
        throw 'FbxToBinConverter execution failed'
    }
}
finally {
    Pop-Location
}

Write-Host "[$caseId] completed"
