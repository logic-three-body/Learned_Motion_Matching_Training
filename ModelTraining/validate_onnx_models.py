import argparse
import datetime
import os
import struct
import sys

import numpy as np
import onnxruntime as ort


def load_features(filename):
    with open(filename, "rb") as f:
        nframes, nfeatures = struct.unpack("II", f.read(8))
        features = np.frombuffer(
            f.read(nframes * nfeatures * 4), dtype=np.float32, count=nframes * nfeatures
        ).reshape([nframes, nfeatures])

        nfeatures = struct.unpack("I", f.read(4))[0]
        f.read(nfeatures * 4)

        nfeatures = struct.unpack("I", f.read(4))[0]
        f.read(nfeatures * 4)

    return {"features": features}


def load_latent(filename):
    with open(filename, "rb") as f:
        nframes, nfeatures = struct.unpack("II", f.read(8))
        latent = np.frombuffer(
            f.read(nframes * nfeatures * 4), dtype=np.float32, count=nframes * nfeatures
        ).reshape([nframes, nfeatures])

    return {"latent": latent}


def _resolve_input_shape(model_name, input_shape, nfeatures, nlatent):
    resolved = []

    if model_name == "projector.onnx":
        preferred = [1, 1, nfeatures]
    elif model_name == "decompressor.onnx":
        preferred = [1, 1, nfeatures + nlatent]
    elif model_name == "stepper.onnx":
        preferred = [1, nfeatures + nlatent]
    else:
        preferred = [1 for _ in input_shape]

    for i, dim in enumerate(input_shape):
        if isinstance(dim, int) and dim > 0:
            resolved.append(dim)
        else:
            resolved.append(preferred[i] if i < len(preferred) else 1)

    return resolved


def _build_input(model_name, shape, nfeatures, nlatent):
    if model_name == "projector.onnx" and len(shape) == 3:
        return np.random.randn(shape[0], shape[1], nfeatures).astype(np.float32)
    if model_name == "decompressor.onnx" and len(shape) == 3:
        return np.random.randn(shape[0], shape[1], nfeatures + nlatent).astype(np.float32)
    if model_name == "stepper.onnx" and len(shape) == 2:
        return np.random.randn(shape[0], nfeatures + nlatent).astype(np.float32)
    return np.random.randn(*shape).astype(np.float32)


def validate_one(models_dir, model_name, nfeatures, nlatent):
    model_path = os.path.join(models_dir, model_name)

    if not os.path.exists(model_path):
        return {
            "model": model_name,
            "ok": False,
            "error": "missing model file",
        }

    try:
        session = ort.InferenceSession(model_path, providers=["CPUExecutionProvider"])
        model_input = session.get_inputs()[0]
        input_name = model_input.name
        resolved_shape = _resolve_input_shape(model_name, model_input.shape, nfeatures, nlatent)

        test_input = _build_input(model_name, resolved_shape, nfeatures, nlatent)
        outputs = session.run(None, {input_name: test_input})

        if len(outputs) == 0:
            return {
                "model": model_name,
                "ok": False,
                "error": "no outputs returned",
            }

        out = np.asarray(outputs[0])
        return {
            "model": model_name,
            "ok": True,
            "input_shape": list(test_input.shape),
            "output_shape": list(out.shape),
            "output_min": float(np.nanmin(out)),
            "output_max": float(np.nanmax(out)),
            "has_nan": bool(np.isnan(out).any()),
        }
    except Exception as exc:
        return {
            "model": model_name,
            "ok": False,
            "error": str(exc),
        }


def write_report(report_path, results):
    ts = datetime.datetime.now().isoformat(timespec="seconds")
    lines = [
        "# ONNX Inference Validation Report",
        "",
        "- Timestamp: %s" % ts,
        "",
        "| Model | Status | Input Shape | Output Shape | Min | Max | NaN | Error |",
        "|---|---|---|---|---:|---:|---|---|",
    ]

    for item in results:
        if item.get("ok"):
            lines.append(
                "| %s | PASS | %s | %s | %.6f | %.6f | %s |  |"
                % (
                    item["model"],
                    item.get("input_shape"),
                    item.get("output_shape"),
                    item.get("output_min", 0.0),
                    item.get("output_max", 0.0),
                    item.get("has_nan"),
                )
            )
        else:
            lines.append(
                "| %s | FAIL |  |  |  |  |  | %s |"
                % (item["model"], item.get("error", "unknown error").replace("|", "/"))
            )

    with open(report_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


def main():
    parser = argparse.ArgumentParser(description="Validate exported ONNX models with one-step CPU inference")
    parser.add_argument("--models-dir", default="./Models")
    parser.add_argument("--database-dir", default="./Database")
    parser.add_argument("--report", default="./Misc/onnx_validation_report.md")
    args = parser.parse_args()

    features_path = os.path.join(args.database_dir, "features.bin")
    latent_path = os.path.join(args.database_dir, "latent.bin")

    if not os.path.exists(features_path):
        print("Missing features.bin: %s" % features_path)
        return 1
    if not os.path.exists(latent_path):
        print("Missing latent.bin: %s" % latent_path)
        return 1

    features = load_features(features_path)["features"]
    latent = load_latent(latent_path)["latent"]

    nfeatures = int(features.shape[1])
    nlatent = int(latent.shape[1])

    model_names = ["decompressor.onnx", "projector.onnx", "stepper.onnx"]
    results = [validate_one(args.models_dir, name, nfeatures, nlatent) for name in model_names]

    report_dir = os.path.dirname(args.report)
    if report_dir:
        os.makedirs(report_dir, exist_ok=True)
    write_report(args.report, results)

    failed = [r for r in results if not r.get("ok") or r.get("has_nan")]
    for r in results:
        if r.get("ok"):
            print("PASS %s input=%s output=%s" % (r["model"], r["input_shape"], r["output_shape"]))
        else:
            print("FAIL %s error=%s" % (r["model"], r.get("error")))

    if failed:
        print("Validation failed. See report: %s" % args.report)
        return 1

    print("All ONNX models passed one-step inference validation.")
    print("Report: %s" % args.report)
    return 0


if __name__ == "__main__":
    sys.exit(main())
