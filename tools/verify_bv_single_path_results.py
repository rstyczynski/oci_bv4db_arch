#!/usr/bin/env python3
"""Independently verify a completed Sprint 30 evidence directory."""
from __future__ import annotations

import json
import math
import re
import statistics
import sys
import copy
from datetime import datetime
from pathlib import Path


PRIMARY = ("data_iops", "redo_p99_ns", "redo_p999_ns", "fra_bw_bytes")
STAMP = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")


def load(path: Path):
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def when(value: str) -> datetime:
    if not STAMP.fullmatch(value):
        raise AssertionError(f"non-canonical UTC timestamp: {value!r}")
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def percentile(job: dict, key: str) -> float:
    values = job.get("write", {}).get("clat_ns", {}).get("percentile", {})
    for candidate in (key, f"{float(key):.6f}"):
        if candidate in values:
            return float(values[candidate])
    raise AssertionError(f"missing write completion percentile {key}")


def metrics(evidence: Path) -> dict:
    fio = load(evidence / "fio.json")
    jobs = fio.get("jobs", [])
    data = [job for job in jobs if job.get("jobname", "").startswith("data-8k")]
    redo = [job for job in jobs if job.get("jobname", "").startswith("redo")]
    fra = [job for job in jobs if job.get("jobname", "").startswith("fra-1m")]
    assert len(data) == 4 and len(redo) == 1 and len(fra) == 1, "FIO job cardinality drift"
    cpu = []
    for host in load(evidence / "iostat.json").get("sysstat", {}).get("hosts", []):
        for sample in host.get("statistics", []):
            cpu.append(100.0 - float(sample["avg-cpu"]["idle"]))
    assert cpu, "missing host iostat CPU samples"
    return {
        "data_iops": sum(float(job[direction].get("iops", 0)) for job in data for direction in ("read", "write")),
        "redo_p99_ns": percentile(redo[0], "99"),
        "redo_p999_ns": percentile(redo[0], "99.9"),
        "fra_bw_bytes": sum(float(fra[0][direction].get("bw_bytes", 0)) for direction in ("read", "write")),
        "cpu_percent": statistics.fmean(cpu),
    }


def summarize(values: list[float]) -> dict:
    median = statistics.median(values)
    mean = statistics.fmean(values)
    return {
        "count": len(values), "median": median, "min": min(values), "max": max(values),
        "mad": statistics.median(abs(value - median) for value in values),
        "cv": statistics.pstdev(values) / mean if len(values) > 1 and mean else 0.0,
    }


def close(left, right) -> bool:
    if left is None or right is None:
        return left is right
    return math.isclose(float(left), float(right), rel_tol=1e-9, abs_tol=1e-6)


def check_summary(actual: dict, expected: dict, label: str) -> None:
    assert actual["count"] == expected["count"], f"{label}: count mismatch"
    for key in ("median", "min", "max", "mad", "cv"):
        assert close(actual[key], expected[key]), f"{label}: {key} mismatch"


def fio_profile(path: Path) -> None:
    text = path.read_text(encoding="ascii")
    required = (
        "ioengine=libaio", "direct=1", "time_based=1", "runtime=600", "ramp_time=60",
        "group_reporting=0", "invalidate=1", "lat_percentiles=1", "percentile_list=95:99:99.9",
        "[data-8k]", "directory=/u02/oradata", "rw=randrw", "rwmixread=70", "bs=8k", "size=32G", "numjobs=4", "iodepth=16",
        "[redo]", "directory=/u03/redo", "rw=write", "bs=4k", "size=4G", "numjobs=1", "iodepth=1", "fdatasync=1",
        "[fra-1m]", "directory=/u04/fra", "rw=readwrite", "bs=1M", "size=16G", "numjobs=1", "iodepth=8", "rate=120M",
    )
    for token in required:
        assert token in text, f"missing FIO option {token} in {path}"


def flatten(value, prefix="") -> dict:
    if isinstance(value, dict):
        result = {}
        for key, item in value.items():
            result.update(flatten(item, f"{prefix}.{key}" if prefix else key))
        return result
    if isinstance(value, list):
        result = {}
        for index, item in enumerate(value):
            result.update(flatten(item, f"{prefix}[{index}]"))
        return result
    return {prefix: value}


def changed_controls(evidence: Path) -> int:
    before, applied = flatten(load(evidence / "controls_before.json")), flatten(load(evidence / "controls_applied.json"))
    return sum(before.get(key) != applied.get(key) for key in set(before) | set(applied))


def errors_clean(evidence: Path) -> bool:
    before, after = load(evidence / "errors_before.json"), load(evidence / "errors_after.json")
    if before.get("kernel_errors") != after.get("kernel_errors") or before.get("iscsi_error_state") != after.get("iscsi_error_state"):
        return False
    tokens = ("RetransSegs", "InErrs", "OutRsts", "InCsumErrors", "ListenDrops", "TCPAbort")
    for key, value in after.get("nstat", {}).items():
        if any(token in key for token in tokens) and float(value) > float(before.get("nstat", {}).get(key, 0)):
            return False
    def network_total(payload: dict) -> float:
        total = 0.0
        for link in payload.get("network", []):
            stats = link.get("stats64") or link.get("stats") or {}
            for direction in ("rx", "tx"):
                for name in ("errors", "dropped", "missed_errors", "crc_errors", "fifo_errors", "carrier_errors"):
                    total += float(stats.get(direction, {}).get(name, 0) or 0)
        return total
    return network_total(after) <= network_total(before)


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: verify_bv_single_path_results.py RUN_DIR")
    root = Path(sys.argv[1]).resolve()
    plan, coverage = load(root / "experiment_plan.json"), load(root / "tunable_coverage.json")
    manifest = load(root / "target_manifest.json")
    manifest_volumes = {item["role"]: item["volume_ocid"] for item in manifest["volumes"]}
    results, recommendation = load(root / "results_index.json"), load(root / "recommendation.json")
    assert plan["vpus"] == [50] and plan["repeats"] == 3
    testable = [row["id"] for row in coverage if row["disposition"] == "testable"]
    assert sorted(plan["candidate_ids"]) == sorted(testable), "plan does not cover every testable candidate"
    assert len(testable) == len(set(testable)), "duplicate candidate ID"
    for candidate in testable:
        assert sum(block.count(candidate) for block in plan["candidate_order_blocks"]) == 3
    assert all(row.get("execution_status") in {"tested", "inconclusive", "failed"} for row in coverage if row["disposition"] == "testable")
    assert all(row.get("discovered_value") is not None and row.get("proposed_value") is not None for row in coverage if row["disposition"] == "testable")
    assert all("execution_status" not in row and row.get("reason") and row.get("evidence") for row in coverage if row["disposition"] != "testable")

    measured = []
    indexed_keys = set()
    for row in results:
        assert row.get("run_id") and row.get("candidate_id") and row.get("attempt_type") and row.get("vpu") == 50
        assert row.get("result") and row.get("restoration_state") and row.get("evidence")
        evidence = root / row["evidence"][0]
        assert evidence.is_dir(), f"missing evidence directory {evidence}"
        if row["attempt_type"] not in {"measurement", "checkpoint"}:
            continue
        assert isinstance(row.get("repetition"), int) and row["repetition"] >= 1
        start, end = when(row["started_at"]), when(row["ended_at"])
        assert start < end and (end - start).total_seconds() >= 600
        for name in (
            "fio.json", "iostat.json", "workload.fio", "controls_before.json", "controls_applied.json",
            "controls_restored.json", "restoration_checks.json", "errors_before.json", "errors_after.json", "state.json", "attempt.json",
            "oci_preflight.json", "guest_preflight.json", "fio_report.html",
        ):
            assert (evidence / name).is_file(), f"missing {name} in {evidence}"
        for context in ("context_before", "context_applied", "context_restored"):
            assert (evidence / context).is_dir() and (evidence / context / "iscsi_sessions.txt").is_file(), f"missing {context} in {evidence}"
        oci_preflight = load(evidence / "oci_preflight.json")
        manifest_volume_rows = {item["role"]: item for item in manifest["volumes"]}
        assert len(oci_preflight) == 5 and all(item["volume"]["vpus-per-gb"] == 50 and "is-multipath" in item["attachment"] and item["attachment"]["is-multipath"] in (False, None) and "multipath-devices" in item["attachment"] and item["attachment"]["multipath-devices"] in (None, []) and item["attachment"]["attachment-type"] == "iscsi" and item["attachment"]["volume-id"] == manifest_volumes[item["role"]] and item["attachment"]["instance-id"] == manifest["compute"]["ocid"] and item["attachment"]["iqn"] == manifest_volume_rows[item["role"]]["iqn"] and item["attachment"]["ipv4"] == manifest_volume_rows[item["role"]]["ipv4"] and item["attachment"]["port"] == manifest_volume_rows[item["role"]]["port"] for item in oci_preflight)
        assert all(load(evidence / "guest_preflight.json").get(key) is True for key in ("sessions_valid", "routes_valid", "devices_unique", "boot_excluded", "multipath_absent", "mounts_valid", "lvm_valid", "socket_congestion_control_valid", "sentinels_valid"))
        assert load(evidence / "controls_before.json") == load(evidence / "controls_restored.json"), f"restore drift in {evidence}"
        restoration = load(evidence / "restoration_checks.json")
        assert restoration.get("byte_equal") is True and restoration.get("tuned_verify_advisory") is False
        assert all(restoration.get(key) == 0 for key in ("restore_controls_exit_code", "capture_controls_exit_code", "live_preflight_exit_code", "stop_rollback_unit_exit_code", "restoration_exit_code"))
        tuned_profile = load(evidence / "controls_before.json").get("tuned_profile")
        if tuned_profile == "__off__":
            assert restoration.get("tuned_verify_exit_code") is None
        else:
            assert restoration.get("tuned_verify_exit_code") == 0
            tuned_log = evidence / "tuned_verify.txt"
            assert tuned_log.is_file() and "exit_code=0" in tuned_log.read_text(encoding="ascii")
        states = [item["state"] for item in load(evidence / "state.json")]
        for state in ("planned", "applying", "active", "measuring", "restoring", "restored", "passed"):
            assert state in states, f"missing {state} transition in {evidence}"
        fio_profile(evidence / "workload.fio")
        item = dict(row)
        item["metrics"] = metrics(evidence)
        measured.append(item)
        indexed_keys.add((row["candidate_id"], row["attempt_type"], row["repetition"], row["started_at"], row["ended_at"]))

    performance = [row for row in measured if row["attempt_type"] == "measurement"]
    initial = [row for row in performance if row["candidate_id"] == "REGULAR_BASELINE_INITIAL"]
    final = [row for row in performance if row["candidate_id"] == "REGULAR_BASELINE_FINAL"]
    assert 3 <= len(initial) <= 5 and 3 <= len(final) <= 5
    baseline = {name: summarize([row["metrics"][name] for row in initial]) for name in PRIMARY}
    final_baseline = {name: summarize([row["metrics"][name] for row in final]) for name in PRIMARY}
    for name in PRIMARY:
        check_summary(recommendation["baseline"][name], baseline[name], f"baseline {name}")
        check_summary(recommendation["final_baseline"][name], final_baseline[name], f"final baseline {name}")
    drift = [name for name in PRIMARY if abs((final_baseline[name]["median"] - baseline[name]["median"]) / baseline[name]["median"]) > max(0.05, 2 * baseline[name]["cv"])]
    assert recommendation["baseline_drift_metrics"] == drift == [], "baseline drift reconciliation failed"

    eligible = []
    computed = {}
    baseline_cpu = summarize([row["metrics"]["cpu_percent"] for row in initial])
    for candidate in testable:
        rows = [row for row in performance if row["candidate_id"] == candidate]
        assert 3 <= len(rows) <= 5, f"invalid repetition count for {candidate}"
        stats = {name: summarize([row["metrics"][name] for row in rows]) for name in PRIMARY}
        stable = all(value["cv"] <= 0.05 for value in stats.values())
        improvements, regressions, gains = [], [], {}
        for name in PRIMARY:
            ratio = (stats[name]["median"] - baseline[name]["median"]) / baseline[name]["median"]
            gain = ratio if name in {"data_iops", "fra_bw_bytes"} else -ratio
            threshold = max(0.05, 2 * baseline[name]["cv"])
            gains[name] = gain
            if gain > threshold:
                improvements.append(name)
            if gain < -threshold:
                regressions.append(name)
        candidate_cpu = summarize([row["metrics"]["cpu_percent"] for row in rows])
        cpu_guard = baseline_cpu["median"] not in (None, 0) and math.isfinite(candidate_cpu["median"]) and candidate_cpu["median"] <= baseline_cpu["median"] * 1.10
        clean = all(errors_clean(root / row["evidence"][0]) for row in rows)
        changed = max(changed_controls(root / row["evidence"][0]) for row in rows)
        is_eligible = stable and bool(improvements) and not regressions and cpu_guard and clean
        computed[candidate] = {"gains": gains, "p999": stats["redo_p999_ns"]["median"], "cpu": candidate_cpu["median"], "changed": changed}
        for name in PRIMARY:
            check_summary(recommendation["candidates"][candidate]["statistics"][name], stats[name], f"{candidate} {name}")
        assert recommendation["candidates"][candidate]["stable"] == stable
        assert recommendation["candidates"][candidate]["improvements"] == improvements
        assert recommendation["candidates"][candidate]["regressions"] == regressions
        assert recommendation["candidates"][candidate]["cpu_guard"] == cpu_guard
        assert recommendation["candidates"][candidate]["errors_clean"] == clean
        assert recommendation["candidates"][candidate]["changed_controls"] == changed
        assert recommendation["candidates"][candidate]["eligible"] == is_eligible
        if is_eligible:
            eligible.append(candidate)
    pareto = []
    for candidate in eligible:
        dominated = any(other != candidate and all(computed[other]["gains"][name] >= computed[candidate]["gains"][name] for name in PRIMARY) and any(computed[other]["gains"][name] > computed[candidate]["gains"][name] for name in PRIMARY) for other in eligible)
        if not dominated:
            pareto.append(candidate)
    pareto.sort(key=lambda item: (computed[item]["p999"], computed[item]["cpu"], computed[item]["changed"], item))
    assert recommendation["eligible_candidates"] == eligible
    assert recommendation["pareto_candidates"] == pareto
    assert recommendation["decision"] == (pareto[0] if pareto else "REGULAR_BASELINE")

    raw, windows = load(root / "oci_metrics_raw.json"), load(root / "oci_metrics_attempt_windows.json")
    assert len(windows) == len(indexed_keys)
    for window in windows:
        key = (window["candidate_id"], window["attempt_type"], window["repetition"], window["started_at"], window["ended_at"])
        assert key in indexed_keys
        start, end = when(window["started_at"]), when(window["ended_at"])
        assert len(window["metrics"]) == len(raw)
        for source, indexed in zip(raw, window["metrics"], strict=True):
            expected_row = copy.deepcopy(source)
            for series in expected_row.get("payload", {}).get("data", []):
                series["aggregated-datapoints"] = [point for point in series.get("aggregated-datapoints", []) if start <= when(point["timestamp"]) <= end]
            expected = sum(len(series.get("aggregated-datapoints", [])) for series in expected_row.get("payload", {}).get("data", []))
            expected_row["attempt_datapoint_count"] = expected
            assert expected >= 8 and indexed == expected_row
    for report in ("fio_analysis.md", "fio_report.html", "sprint_30_summary.md"):
        text = (root / report).read_text(encoding="utf-8")
        assert recommendation["decision"] in text
        assert all(candidate in text for candidate in testable)
    assert "not a supported multipath/UHP entitlement" in (root / "sprint_30_summary.md").read_text(encoding="utf-8")
    print(f"verified {len(results)} indexed rows and {len(testable)} testable candidates")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
