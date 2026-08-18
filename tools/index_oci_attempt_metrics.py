#!/usr/bin/env python3
"""Index OCI Monitoring datapoints into exact Sprint 30 FIO attempt windows."""
from __future__ import annotations

import json
import sys
from datetime import datetime
from pathlib import Path


def timestamp(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def main() -> int:
    if len(sys.argv) != 4:
        raise SystemExit("usage: index_oci_attempt_metrics.py RESULTS RAW OUTPUT")
    results = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    raw = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
    windows = []
    complete = True
    for attempt in results:
        if attempt.get("attempt_type") not in {"measurement", "checkpoint"}:
            continue
        start, end = timestamp(attempt["started_at"]), timestamp(attempt["ended_at"])
        metrics = []
        for source in raw:
            row = json.loads(json.dumps(source))
            for series in row.get("payload", {}).get("data", []):
                points = series.get("aggregated-datapoints", [])
                series["aggregated-datapoints"] = [point for point in points if start <= timestamp(point["timestamp"]) <= end]
            count = sum(len(series.get("aggregated-datapoints", [])) for series in row.get("payload", {}).get("data", []))
            row["attempt_datapoint_count"] = count
            metrics.append(row)
            complete &= count >= 8
        windows.append({
            "candidate_id": attempt["candidate_id"],
            "attempt_type": attempt["attempt_type"],
            "repetition": attempt.get("repetition"),
            "started_at": attempt["started_at"],
            "ended_at": attempt["ended_at"],
            "metrics": metrics,
        })
    Path(sys.argv[3]).write_text(json.dumps(windows, indent=2) + "\n", encoding="utf-8")
    return 0 if windows and complete else 1


if __name__ == "__main__":
    raise SystemExit(main())
