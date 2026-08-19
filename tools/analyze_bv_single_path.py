#!/usr/bin/env python3
"""Render Sprint 30 statistics and recommendation from raw attempt evidence."""
from __future__ import annotations

import html
import json
import math
import statistics
import sys
from pathlib import Path


def load(path: Path):
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def percentile(job: dict, key: str) -> float:
    values = job.get("write", {}).get("clat_ns", {}).get("percentile", {})
    for candidate in (key, f"{float(key):.6f}"):
        if candidate in values:
            return float(values[candidate])
    return math.nan


def attempt_metrics(run_dir: Path, row: dict) -> dict:
    evidence = run_dir / row["evidence"][0]
    fio = load(evidence / "fio.json")
    jobs = fio.get("jobs", [])
    data_jobs = [j for j in jobs if j.get("jobname", "").startswith("data-8k")]
    redo_jobs = [j for j in jobs if j.get("jobname", "").startswith("redo")]
    fra_jobs = [j for j in jobs if j.get("jobname", "").startswith("fra-1m")]
    if not data_jobs or len(redo_jobs) != 1 or len(fra_jobs) != 1:
        raise ValueError(f"unexpected fio job set in {evidence}")
    data_iops = sum(float(j.get("read", {}).get("iops", 0)) + float(j.get("write", {}).get("iops", 0)) for j in data_jobs)
    redo = redo_jobs[0]
    fra = fra_jobs[0]
    fra_bw = float(fra.get("read", {}).get("bw_bytes", 0)) + float(fra.get("write", {}).get("bw_bytes", 0))
    fio_cpu_samples = [float(j.get("usr_cpu", 0)) + float(j.get("sys_cpu", 0)) for j in jobs]
    iostat = load(evidence / "iostat.json")
    host_cpu_samples = []
    for host in iostat.get("sysstat", {}).get("hosts", []):
        for sample in host.get("statistics", []):
            try:
                host_cpu_samples.append(100.0 - float(sample.get("avg-cpu", {}).get("idle", 100.0)))
            except (TypeError, ValueError):
                pass
    before = load(evidence / "errors_before.json")
    after = load(evidence / "errors_after.json")
    error_keys = ("RetransSegs", "InErrs", "OutRsts", "InCsumErrors", "ListenDrops", "TCPAbort")
    counter_increase = False
    for key, after_value in after.get("nstat", {}).items():
        if any(token in key for token in error_keys):
            try:
                counter_increase |= float(after_value) > float(before.get("nstat", {}).get(key, 0))
            except (TypeError, ValueError):
                counter_increase = True
    def network_error_total(payload: dict) -> float:
        total = 0.0
        for link in payload.get("network", []):
            for direction in ("rx", "tx"):
                stats = (link.get("stats64") or link.get("stats") or {}).get(direction, {})
                for name in ("errors", "dropped", "missed_errors", "crc_errors", "fifo_errors", "carrier_errors"):
                    try:
                        total += float(stats.get(name, 0) or 0)
                    except (TypeError, ValueError):
                        return math.inf
        return total
    counter_increase |= network_error_total(after) > network_error_total(before)
    job_metrics = {}
    for index, job in enumerate(jobs):
        read, write = job.get("read", {}), job.get("write", {})
        job_metrics[f"{job.get('jobname', 'job')}#{index}"] = {
            "read_iops": float(read.get("iops", 0)), "write_iops": float(write.get("iops", 0)),
            "read_bw_bytes": float(read.get("bw_bytes", 0)), "write_bw_bytes": float(write.get("bw_bytes", 0)),
            "write_p99_ns": percentile(job, "99"), "write_p999_ns": percentile(job, "99.9"),
            "sync_mean_ns": float(job.get("sync", {}).get("lat_ns", {}).get("mean", math.nan)),
        }
    return {
        "data_iops": data_iops,
        "redo_p99_ns": percentile(redo, "99"),
        "redo_p999_ns": percentile(redo, "99.9"),
        "fra_bw_bytes": fra_bw,
        "redo_sync_mean_ns": float(redo.get("sync", {}).get("lat_ns", {}).get("mean", math.nan)),
        "fio_cpu_percent": statistics.fmean(fio_cpu_samples) if fio_cpu_samples else 0.0,
        "cpu_percent": statistics.fmean(host_cpu_samples) if host_cpu_samples else math.nan,
        "errors_clean": not counter_increase and after.get("kernel_errors", "") == before.get("kernel_errors", "") and after.get("iscsi_error_state", "") == before.get("iscsi_error_state", ""),
        "job_metrics": job_metrics,
    }


def summary(values: list[float]) -> dict:
    clean = [v for v in values if not math.isnan(v)]
    if not clean:
        return {"count": 0, "median": None, "min": None, "max": None, "mad": None, "cv": None}
    med = statistics.median(clean)
    mad = statistics.median(abs(v - med) for v in clean)
    mean = statistics.fmean(clean)
    cv = statistics.pstdev(clean) / mean if len(clean) > 1 and mean else 0.0
    return {"count": len(clean), "median": med, "min": min(clean), "max": max(clean), "mad": mad, "cv": cv}


def changed_control_count(run_dir: Path, row: dict) -> int:
    evidence = run_dir / row["evidence"][0]
    before = load(evidence / "controls_before.json")
    applied = load(evidence / "controls_applied.json")
    def flatten(value, prefix=""):
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
    left, right = flatten(before), flatten(applied)
    return sum(left.get(key) != right.get(key) for key in set(left) | set(right))


def main() -> int:
    special_mode = sys.argv[1] if len(sys.argv) == 3 and sys.argv[1] in {"--shortlist", "--checkpoint-drift", "--final-drift"} else ""
    if len(sys.argv) != 2 and not special_mode:
        raise SystemExit("usage: analyze_bv_single_path.py [--shortlist|--checkpoint-drift|--final-drift] RUN_DIR")
    run_dir = Path(sys.argv[2] if special_mode else sys.argv[1]).resolve()
    rows = load(run_dir / "results_index.json")
    coverage = load(run_dir / "tunable_coverage.json")
    passed_fio_rows = [r for r in rows if r.get("attempt_type") in {"measurement", "checkpoint"} and r.get("result") == "passed"]
    for row in passed_fio_rows:
        row["metrics"] = attempt_metrics(run_dir, row)
    measurement_rows = [r for r in passed_fio_rows if r.get("attempt_type") == "measurement"]
    if special_mode == "--shortlist":
        initial = [r for r in measurement_rows if r["candidate_id"] == "REGULAR_BASELINE_INITIAL"]
        if not initial:
            raise ValueError("accepted archived baseline is missing")
        names = ("data_iops", "redo_p99_ns", "redo_p999_ns", "fra_bw_bytes")
        base = {name: summary([row["metrics"][name] for row in initial])["median"] for name in names}
        baseline_cpu = summary([row["metrics"]["cpu_percent"] for row in initial])["median"]
        for candidate_id in [c["id"] for c in coverage if c.get("disposition") == "testable"]:
            rows = [r for r in measurement_rows if r["candidate_id"] == candidate_id]
            if len(rows) != 1:
                continue
            gains = {
                name: ((rows[0]["metrics"][name] - base[name]) / base[name]) * (1 if name in {"data_iops", "fra_bw_bytes"} else -1)
                for name in names if base[name]
            }
            improves = any(value > 0.05 for value in gains.values())
            regresses = any(value < -0.05 for value in gains.values())
            cpu_ok = math.isfinite(rows[0]["metrics"]["cpu_percent"]) and baseline_cpu and rows[0]["metrics"]["cpu_percent"] <= baseline_cpu * 1.10
            if improves and not regresses and cpu_ok and rows[0]["metrics"]["errors_clean"]:
                print(candidate_id)
        return 0
    if special_mode in {"--checkpoint-drift", "--final-drift"}:
        names = ("data_iops", "redo_p99_ns", "redo_p999_ns", "fra_bw_bytes")
        initial = [r for r in measurement_rows if r["candidate_id"] == "REGULAR_BASELINE_INITIAL"]
        base = {name: summary([r["metrics"][name] for r in initial]) for name in names}
        if special_mode == "--final-drift":
            final = [r for r in measurement_rows if r["candidate_id"] == "REGULAR_BASELINE_FINAL"]
            comparison = {name: summary([r["metrics"][name] for r in final]) for name in names}
            for name in names:
                median = base[name]["median"]
                other = comparison[name]["median"]
                if median in (None, 0) or other is None or abs((other - median) / median) > 0.05:
                    print(name)
            return 0
        for row in (r for r in passed_fio_rows if r.get("attempt_type") == "checkpoint"):
            drifted = False
            for name in names:
                median = base[name]["median"]
                if median in (None, 0):
                    drifted = True
                    continue
                threshold = 0.05
                ratio = (row["metrics"][name] - median) / median
                drifted |= abs(ratio) > threshold
            if drifted:
                print(row["candidate_id"])
        return 0
    initial_rows = [r for r in measurement_rows if r["candidate_id"] == "REGULAR_BASELINE_INITIAL"]
    if not initial_rows:
        raise ValueError("accepted archived baseline is missing")
    metric_names = ("data_iops", "redo_p99_ns", "redo_p999_ns", "fra_bw_bytes")
    baseline = {name: summary([r["metrics"][name] for r in initial_rows]) for name in metric_names}
    baseline_drift = []
    candidate_ids = [c["id"] for c in coverage if c.get("disposition") == "testable"]
    def job_statistics(selected_rows: list[dict]) -> dict:
        job_names = sorted({name for row in selected_rows for name in row["metrics"]["job_metrics"]})
        return {
            job: {
                metric: summary([row["metrics"]["job_metrics"][job][metric] for row in selected_rows if job in row["metrics"]["job_metrics"]])
                for metric in ("read_iops", "write_iops", "read_bw_bytes", "write_bw_bytes", "write_p99_ns", "write_p999_ns", "sync_mean_ns")
            }
            for job in job_names
        }
    baseline_job_statistics = job_statistics(initial_rows)
    candidates = {}
    eligible = []
    for candidate_id in candidate_ids:
        candidate_rows = [r for r in measurement_rows if r["candidate_id"] == candidate_id]
        stats = {name: summary([r["metrics"][name] for r in candidate_rows]) for name in metric_names}
        stable = len(candidate_rows) >= 3 and all(v["cv"] is not None and v["cv"] <= 0.05 for v in stats.values())
        improvements = []
        regressions = []
        gains = {}
        for name in metric_names:
            base = baseline[name]
            value = stats[name]
            if base["median"] in (None, 0) or value["median"] is None:
                continue
            threshold = 0.05
            ratio = (value["median"] - base["median"]) / base["median"]
            higher_is_better = name in {"data_iops", "fra_bw_bytes"}
            gain = ratio if higher_is_better else -ratio
            gains[name] = gain
            if gain > threshold:
                improvements.append(name)
            if gain < -threshold:
                regressions.append(name)
        candidate_cpu = summary([r["metrics"]["cpu_percent"] for r in candidate_rows])
        baseline_cpu = summary([r["metrics"]["cpu_percent"] for r in initial_rows])
        cpu_guard = baseline_cpu["median"] not in (None, 0) and candidate_cpu["median"] is not None and math.isfinite(candidate_cpu["median"]) and candidate_cpu["median"] <= baseline_cpu["median"] * 1.10
        errors_clean = all(r["metrics"]["errors_clean"] for r in candidate_rows)
        is_eligible = stable and bool(improvements) and not regressions and cpu_guard and errors_clean and not baseline_drift
        candidates[candidate_id] = {
            "repetitions": len(candidate_rows), "stable": stable, "statistics": stats,
            "job_statistics": job_statistics(candidate_rows),
            "redo_sync_mean_ns": summary([r["metrics"]["redo_sync_mean_ns"] for r in candidate_rows]),
            "cpu": candidate_cpu, "cpu_guard": cpu_guard, "errors_clean": errors_clean,
            "improvements": improvements, "regressions": regressions, "gains": gains,
            "changed_controls": max(changed_control_count(run_dir, row) for row in candidate_rows) if candidate_rows else 0,
            "evidence": [r["evidence"][0] for r in candidate_rows],
            "eligible": is_eligible,
        }
        if is_eligible:
            eligible.append(candidate_id)
    pareto = []
    for candidate_id in eligible:
        dominated = any(
            other != candidate_id
            and all(candidates[other]["gains"].get(name, -math.inf) >= candidates[candidate_id]["gains"].get(name, -math.inf) for name in metric_names)
            and any(candidates[other]["gains"].get(name, -math.inf) > candidates[candidate_id]["gains"].get(name, -math.inf) for name in metric_names)
            for other in eligible
        )
        if not dominated:
            pareto.append(candidate_id)
    pareto.sort(key=lambda item: (candidates[item]["statistics"]["redo_p999_ns"]["median"] or math.inf, candidates[item]["cpu"]["median"] or math.inf, candidates[item]["changed_controls"], item))
    decision = pareto[0] if pareto else "REGULAR_BASELINE"
    recommendation = {
        "vpu": 50,
        "decision": decision,
        "reason": "Pareto-optimal stable non-regressing candidate" if pareto else "no stable candidate cleared improvement and regression thresholds",
        "evidence": ["baseline_reference.json", "results_index.json", "tunable_coverage.json", "attempts/"],
        "measurement_runs": len(measurement_rows),
        "baseline": baseline,
        "baseline_job_statistics": baseline_job_statistics,
        "baseline_source": "archived",
        "baseline_remeasured": False,
        "baseline_drift_metrics": baseline_drift,
        "candidates": candidates,
        "eligible_candidates": eligible,
        "pareto_candidates": pareto,
    }
    (run_dir / "recommendation.json").write_text(json.dumps(recommendation, indent=2) + "\n", encoding="utf-8")
    lines = ["# Sprint 30 FIO analysis", "", "- Fixed tier: `50 VPUs/GB`", "- Baseline source: archived accepted evidence; not remeasured", f"- Successful measured repetitions including archived baseline: `{len(measurement_rows)}`", f"- Recommendation: `{decision}`", "", "## Candidate statistics", "", "| Candidate | Stable | Eligible | Improvements | Regressions | Evidence |", "| --- | --- | --- | --- | --- | --- |"]
    for candidate_id in candidate_ids:
        item = candidates[candidate_id]
        evidence_links = ", ".join(f"[{Path(path).name}]({path}/fio_report.html)" for path in item["evidence"])
        lines.append(f"| `{candidate_id}` | {item['stable']} | {item['eligible']} | {', '.join(item['improvements']) or '-'} | {', '.join(item['regressions']) or '-'} | {evidence_links} |")
    lines += ["", "## Per-job statistics", "", "| Candidate | Job | Metric | Median | Min | Max | MAD | CV |", "| --- | --- | --- | ---: | ---: | ---: | ---: | ---: |"]
    for candidate_id in candidate_ids:
        for job, metrics in candidates[candidate_id]["job_statistics"].items():
            for metric, values in metrics.items():
                lines.append(f"| `{candidate_id}` | `{job}` | `{metric}` | {values['median']} | {values['min']} | {values['max']} | {values['mad']} | {values['cv']} |")
    (run_dir / "fio_analysis.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    table_rows = "".join(
        f"<tr><td>{html.escape(cid)}</td><td>{str(candidates[cid]['stable']).lower()}</td><td>{str(candidates[cid]['eligible']).lower()}</td>"
        f"<td>{candidates[cid]['statistics']['data_iops']['median']}</td><td>{candidates[cid]['statistics']['redo_p99_ns']['median']}</td>"
        f"<td>{candidates[cid]['statistics']['redo_p999_ns']['median']}</td><td>{candidates[cid]['statistics']['fra_bw_bytes']['median']}</td>"
        f"<td>{candidates[cid]['redo_sync_mean_ns']['median']}</td><td>{candidates[cid]['cpu']['median']}</td>"
        f"<td>{html.escape(', '.join(candidates[cid]['improvements']) or '-')}</td><td>{html.escape(', '.join(candidates[cid]['regressions']) or '-')}</td></tr>"
        for cid in candidate_ids
    )
    report = f'<!doctype html><html><head><meta charset="utf-8"><title>Sprint 30 FIO report</title></head><body><h1>Sprint 30 FIO report</h1><p>Fixed tier: 50 VPUs/GB.</p><p>Baseline: archived accepted evidence; not remeasured.</p><p>Recommendation: <code>{html.escape(decision)}</code></p><table><thead><tr><th>Candidate</th><th>Stable</th><th>Eligible</th><th>DATA IOPS median</th><th>REDO p99 ns</th><th>REDO p99.9 ns</th><th>FRA B/s</th><th>REDO sync mean ns</th><th>Host CPU %</th><th>Improvements</th><th>Regressions</th></tr></thead><tbody>{table_rows}</tbody></table></body></html>\n'
    (run_dir / "fio_report.html").write_text(report, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
