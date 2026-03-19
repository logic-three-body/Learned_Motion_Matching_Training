# Skill Loop Closure

## Goal
Create a reproducible, non-global, per-case execution flow for this repository.

## What Was Standardized
- Added per-case isolated virtual environments.
- Added parameterized training via environment variables for smoke and full runs.
- Added case scripts and one orchestrator script with parallel final-stage training.
- Added centralized logs for case-level diagnostics.
- Added ONNX runtime inference validation stage for exported models.

## Key Decisions
- Keep source model code intact except minimal runtime parameterization.
- Use smoke mode for fast validation and full mode for final model quality.
- Preserve original default paths while enabling LMM_BIN_DIR override.

## Recurring Risks And Mitigations
- FBX SDK setup drift:
  - Mitigation: enforce FBXSDK_ROOT and validate libfbxsdk.dll discovery in case-01.
- Long training cycles:
  - Mitigation: expose NIter via environment and smoke profile.
- Environment contamination:
  - Mitigation: one venv per case only.

## Verification Pattern
For each case, verify:
- command exits successfully
- expected output artifacts exist and are non-empty
- dedicated log file was generated

## Implementation Outcome (Current Machine)
- Completed: case-01 through case-05 (smoke-validated training chain)
- Added: case-06 ONNX one-step inference validation script
- Produced artifacts verified:
  - Animations/LAFAN1BIN/*.bin
  - Animations/LAFAN1BIN/boneParentInfo.bin
  - ModelTraining/Database/database.bin
  - ModelTraining/Database/features.bin
  - ModelTraining/Database/latent.bin
  - ModelTraining/Models/decompressor.onnx
  - ModelTraining/Models/projector.onnx
  - ModelTraining/Models/stepper.onnx

## Additional Lessons
- Newer torch ONNX export path may require onnx and onnxscript; these were added to case requirements.
- On Windows scientific stacks, OpenMP duplicate runtime conflicts can happen; setting KMP_DUPLICATE_LIB_OK=TRUE in case scripts prevented hard failure during smoke validation.

## Hardware Best Practice (Final)
- Machine baseline used for tuning: Ryzen 9 7950X, 64 GB RAM, 2x RTX 4090.
- Training envs must use CUDA-enabled torch builds; CPU-only torch removed key acceleration paths.
- Batch sizing is case-sensitive and non-monotonic:
  - case-04 performed best at smaller batches (`BatchSize=32`).
  - case-05 performed best at medium batches (`BatchSize=64`).
  - case-03 had minor gains at larger batches (`BatchSize=256`).
- Best wall-clock strategy is cross-case dual-GPU scheduling, not multi-GPU inside one small model:
  - run case-03 first on `cuda:1`.
  - run case-04 on `cuda:0` and case-05 on `cuda:1` in parallel.
- Latest benchmark report confirms final ranking:
  - CPU baseline: `197.373s`
  - Single GPU tuned: `72.519s`
  - Dual GPU tuned (04/05 parallel): `53.100s`

## Operational Closure
- Best-practice runner: `scripts/run_training_best_hw.ps1`
- Benchmark reproducer: `scripts/benchmark_training_hardware.ps1`
- Benchmark output artifact: `docs/hardware_benchmark_latest.md`

## Reuse Checklist
- Run scripts/run_all_cases.ps1 -Smoke first.
- Switch to full run only after smoke artifacts validate.
- Keep docs updated when dependency versions or toolchain versions change.
