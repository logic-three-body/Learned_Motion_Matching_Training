# Learned Motion Matching Training Runbook (Windows)

## Scope
This runbook configures and runs all 6 cases with isolated environments:
- case-01-dataprocess
- case-02-generate-db
- case-03-train-decompressor
- case-04-train-projector
- case-05-train-stepper
- case-06-validate-inference

## Prerequisites
- Windows with PowerShell 5.1+
- Python 3.10+ available as py or python
- Visual Studio Build Tools (C++ workload)
- Autodesk FBX SDK installed and FBXSDK_ROOT set (required for case-01)
- Git LFS installed (required to fetch BVH files)

Set FBX SDK root (example):

```powershell
$env:FBXSDK_ROOT = 'C:\Program Files\Autodesk\FBX\FBX SDK\2020.3.2'
```

Fetch BVH assets before case-01:

```powershell
git lfs pull
```

If Autodesk FBX SDK is not installed, the case-01 script can also auto-detect supported Houdini FBX SDK layout when available.

## Case Environments
Each case has a dedicated venv under:
- .venvs/case-01-dataprocess
- .venvs/case-02-generate-db
- .venvs/case-03-train-decompressor
- .venvs/case-04-train-projector
- .venvs/case-05-train-stepper
- .venvs/case-06-validate-inference

## Run Individual Cases
From repository root:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\cases\case-01-dataprocess.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\cases\case-02-generate-db.ps1 -InstallDeps
powershell -ExecutionPolicy Bypass -File .\scripts\cases\case-03-train-decompressor.ps1 -InstallDeps -NIter 20
powershell -ExecutionPolicy Bypass -File .\scripts\cases\case-04-train-projector.ps1 -InstallDeps -NIter 20
powershell -ExecutionPolicy Bypass -File .\scripts\cases\case-05-train-stepper.ps1 -InstallDeps -NIter 20
powershell -ExecutionPolicy Bypass -File .\scripts\cases\case-06-validate-inference.ps1 -InstallDeps
```

## Run All Cases
Smoke run (short training, parallel case-04 and case-05):

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_all_cases.ps1 -InstallDeps -Smoke
```

Full run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_all_cases.ps1 -InstallDeps
```

## Best Hardware Workflow (Validated)
This repository now includes a tuned dual-GPU execution profile for the current machine
(Ryzen 9 7950X + 2x RTX 4090).

Run the tuned pipeline:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_training_best_hw.ps1 -Smoke
```

Run benchmark validation and write a report:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\benchmark_training_hardware.ps1
```

Current tuned settings:
- case-03: `Device=cuda:1`, `BatchSize=256`
- case-04: `Device=cuda:0`, `BatchSize=32`
- case-05: `Device=cuda:1`, `BatchSize=64`
- case-04 and case-05 execute in parallel.

Latest measured summary (`docs/hardware_benchmark_latest.md`):
- CPU baseline total: `197.373s`
- Single GPU tuned total: `72.519s`
- Dual GPU tuned total: `53.100s`

If FBXSDK is not ready yet, skip case-01 temporarily:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_all_cases.ps1 -InstallDeps -Smoke -SkipCase01
```

## Expected Artifacts
- Animations/LAFAN1BIN/*.bin and boneParentInfo.bin from case-01
- ModelTraining/Database/database.bin from case-02
- ModelTraining/Database/features.bin from case-02
- ModelTraining/Database/latent.bin from case-03
- ModelTraining/Models/decompressor.onnx from case-03
- ModelTraining/Models/projector.onnx from case-04
- ModelTraining/Models/stepper.onnx from case-05
- ModelTraining/Misc/onnx_validation_report.md from case-06

## Logs
- Per-case logs are written to logs/*.log

## Current Validation Status (This Implementation)
- case-01-dataprocess: completed
- case-02-generate-db: completed
- case-03-train-decompressor: completed (smoke)
- case-04-train-projector: completed (smoke)
- case-05-train-stepper: completed (smoke)
- case-06-validate-inference: implemented and ready

Verified artifacts from the executed run:
- Animations/LAFAN1BIN/*.bin
- Animations/LAFAN1BIN/boneParentInfo.bin
- ModelTraining/Database/database.bin
- ModelTraining/Database/features.bin
- ModelTraining/Database/latent.bin
- ModelTraining/Models/decompressor.onnx
- ModelTraining/Models/projector.onnx
- ModelTraining/Models/stepper.onnx

Recent run logs:
- logs/case-02-generate-db-*.log
- logs/case-03-train-decompressor-*.log
- logs/case-04-train-projector-*.log
- logs/case-05-train-stepper-*.log

## Subagent Parallelization Mapping
Recommended split if running with coding subagents:
- Subagent A: case-01-dataprocess
- Subagent B: case-02-generate-db + case-03-train-decompressor
- Subagent C: case-04-train-projector + case-05-train-stepper

## Troubleshooting
- msbuild missing:
  - Install Visual Studio Build Tools with Desktop development with C++.
- FBXSDK dll missing at runtime:
  - Ensure libfbxsdk.dll exists under FBXSDK_ROOT and rerun case-01.
- Python package install timeout:
  - Re-run with stable network and consider local mirror.
- Training too slow:
  - Use smoke mode or lower NIter.
- case-01 immediately fails with FBXSDK_ROOT not set:
  - Install Autodesk FBX SDK.
  - Set the variable in current shell:
    - $env:FBXSDK_ROOT = 'C:\\Program Files\\Autodesk\\FBX\\FBX SDK\\2020.3.2'
  - Re-run:
    - powershell -ExecutionPolicy Bypass -File .\\scripts\\cases\\case-01-dataprocess.ps1
