#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import math
import pathlib
import sys
import zipfile


def _format_bytes(value: int) -> str:
    mib = value / (1024 * 1024)
    return f"{value:,} B ({mib:.2f} MiB)"


def _artifact_kind(path: pathlib.Path) -> str:
    suffix = path.suffix.lower()
    if suffix == ".aab":
        return "aab"
    if suffix == ".apk":
        return "apk"
    raise ValueError(f"Unsupported artifact type: {path}. Expected .aab or .apk")


def _bucket_for_zip_path(path: str, kind: str) -> str:
    if kind == "aab":
        if path.startswith("base/lib/"):
            return "native_libs"
        if path.startswith("base/dex/"):
            return "dex"
        if path.startswith("base/assets/"):
            return "assets"
        if path.startswith("base/res/"):
            return "resources"
        if path.startswith("BUNDLE-METADATA/"):
            return "bundle_metadata"
        if path.startswith("META-INF/"):
            return "meta_inf"
        return "other"

    if path.startswith("lib/"):
        return "native_libs"
    if path.startswith("assets/"):
        return "assets"
    if path.startswith("res/") or path == "resources.arsc":
        return "resources"
    if path.startswith("META-INF/"):
        return "meta_inf"
    if path.startswith("classes") and path.endswith(".dex"):
        return "dex"
    return "other"


def _read_zip_buckets(path: pathlib.Path, kind: str) -> dict[str, int]:
    buckets: dict[str, int] = {
        "native_libs": 0,
        "dex": 0,
        "assets": 0,
        "resources": 0,
        "bundle_metadata": 0,
        "meta_inf": 0,
        "other": 0,
    }
    with zipfile.ZipFile(path, "r") as archive:
        for info in archive.infolist():
            if info.is_dir():
                continue
            bucket = _bucket_for_zip_path(info.filename, kind)
            buckets[bucket] += info.file_size
    return buckets


def _top_bucket_deltas(base: dict[str, int], head: dict[str, int], limit: int = 5) -> list[tuple[str, int]]:
    all_keys = sorted(set(base.keys()) | set(head.keys()))
    deltas = [(key, head.get(key, 0) - base.get(key, 0)) for key in all_keys]
    deltas.sort(key=lambda item: item[1], reverse=True)
    return deltas[:limit]


def _pct_delta(base: int, head: int) -> float:
    if base <= 0:
        return math.inf if head > 0 else 0.0
    return ((head - base) / base) * 100.0


def _threshold_exceeded(delta: int, pct_delta: float, abs_threshold: int, pct_threshold: float) -> bool:
    return delta > abs_threshold or pct_delta > pct_threshold


def _markdown_report(
    artifact_name: str,
    base_size: int,
    head_size: int,
    delta: int,
    pct_delta: float,
    abs_threshold: int,
    pct_threshold: float,
    exceeded: bool,
    top_deltas: list[tuple[str, int]],
) -> str:
    status = "FAIL" if exceeded else "PASS"
    pct_text = "inf" if math.isinf(pct_delta) else f"{pct_delta:.2f}%"
    lines = [
        "## Android App Size Report",
        "",
        f"Status: **{status}**",
        "",
        "| Metric | Base | Head | Delta |",
        "|---|---:|---:|---:|",
        f"| `{artifact_name}` | {_format_bytes(base_size)} | {_format_bytes(head_size)} | {_format_bytes(delta)} ({pct_text}) |",
        "",
        f"Thresholds: max delta `{_format_bytes(abs_threshold)}` OR `{pct_threshold:.2f}%`.",
        "",
        "Top artifact bucket deltas (uncompressed bytes):",
    ]

    for name, bucket_delta in top_deltas:
        sign = "+" if bucket_delta >= 0 else ""
        lines.append(f"- `{name}`: {sign}{_format_bytes(bucket_delta)}")

    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description="Compare Android artifact sizes and enforce thresholds.")
    parser.add_argument("--base-artifact", required=True, help="Path to base APK/AAB")
    parser.add_argument("--head-artifact", required=True, help="Path to head APK/AAB")
    parser.add_argument("--max-delta-bytes", type=int, required=True, help="Fail if delta exceeds this many bytes")
    parser.add_argument("--max-delta-percent", type=float, required=True, help="Fail if percent delta exceeds this value")
    parser.add_argument("--json-out", required=True, help="Output JSON report path")
    parser.add_argument("--summary-out", required=True, help="Output Markdown summary path")
    args = parser.parse_args()

    base_path = pathlib.Path(args.base_artifact)
    head_path = pathlib.Path(args.head_artifact)

    if not base_path.exists():
        raise FileNotFoundError(f"Base artifact not found: {base_path}")
    if not head_path.exists():
        raise FileNotFoundError(f"Head artifact not found: {head_path}")

    base_kind = _artifact_kind(base_path)
    head_kind = _artifact_kind(head_path)
    if base_kind != head_kind:
        raise ValueError(f"Artifact kinds do not match: {base_kind} vs {head_kind}")

    base_size = base_path.stat().st_size
    head_size = head_path.stat().st_size
    delta = head_size - base_size
    pct_delta = _pct_delta(base_size, head_size)
    exceeded = _threshold_exceeded(delta, pct_delta, args.max_delta_bytes, args.max_delta_percent)

    base_buckets = _read_zip_buckets(base_path, base_kind)
    head_buckets = _read_zip_buckets(head_path, head_kind)
    top_deltas = _top_bucket_deltas(base_buckets, head_buckets)

    summary = _markdown_report(
        artifact_name=head_path.name,
        base_size=base_size,
        head_size=head_size,
        delta=delta,
        pct_delta=pct_delta,
        abs_threshold=args.max_delta_bytes,
        pct_threshold=args.max_delta_percent,
        exceeded=exceeded,
        top_deltas=top_deltas,
    )

    report = {
        "base_artifact": str(base_path),
        "head_artifact": str(head_path),
        "artifact_kind": base_kind,
        "base_size_bytes": base_size,
        "head_size_bytes": head_size,
        "delta_bytes": delta,
        "delta_percent": None if math.isinf(pct_delta) else round(pct_delta, 4),
        "thresholds": {
            "max_delta_bytes": args.max_delta_bytes,
            "max_delta_percent": args.max_delta_percent,
        },
        "status": "fail" if exceeded else "pass",
        "base_buckets_bytes": base_buckets,
        "head_buckets_bytes": head_buckets,
        "top_bucket_deltas_bytes": [{"bucket": name, "delta_bytes": value} for name, value in top_deltas],
    }

    json_out_path = pathlib.Path(args.json_out)
    summary_out_path = pathlib.Path(args.summary_out)
    json_out_path.parent.mkdir(parents=True, exist_ok=True)
    summary_out_path.parent.mkdir(parents=True, exist_ok=True)

    json_out_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    summary_out_path.write_text(summary, encoding="utf-8")

    sys.stdout.write(summary)
    return 1 if exceeded else 0


if __name__ == "__main__":
    raise SystemExit(main())
