#!/usr/bin/env python3
"""Render a human-readable Markdown report from one Sprint 30 attempt."""

from __future__ import annotations

import argparse
import json
import math
import statistics
from datetime import datetime
from pathlib import Path


def load(path: Path, default):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError):
        return default


def number(value, default=0.0) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def percentile(job: dict, value: str):
    values = job.get("write", {}).get("clat_ns", {}).get("percentile", {})
    for key in (value, f"{float(value):.6f}"):
        if key in values:
            return number(values[key], math.nan)
    return math.nan


def milliseconds(nanoseconds: float) -> str:
    return "n/a" if math.isnan(nanoseconds) else f"{nanoseconds / 1_000_000:.3f}"


def host_cpu(iostat: dict):
    samples = []
    for host in iostat.get("sysstat", {}).get("hosts", []):
        for sample in host.get("statistics", []):
            idle = sample.get("avg-cpu", {}).get("idle")
            if idle is not None:
                samples.append(100.0 - number(idle, 100.0))
    return statistics.fmean(samples) if samples else math.nan


def network_error_total(payload: dict) -> float:
    total = 0.0
    for link in payload.get("network", []):
        stats = link.get("stats64") or link.get("stats") or {}
        for direction in ("rx", "tx"):
            values = stats.get(direction, {})
            for key in ("errors", "dropped", "missed_errors", "crc_errors", "fifo_errors", "carrier_errors"):
                total += number(values.get(key))
    return total


def monitored_errors_clean(before: dict, after: dict) -> bool:
    tokens = ("RetransSegs", "InErrs", "OutRsts", "InCsumErrors", "ListenDrops", "TCPAbort")
    for key, after_value in after.get("nstat", {}).items():
        if any(token in key for token in tokens) and number(after_value) > number(before.get("nstat", {}).get(key)):
            return False
    return (
        network_error_total(after) <= network_error_total(before)
        and after.get("kernel_errors", "") == before.get("kernel_errors", "")
        and after.get("iscsi_error_state", "") == before.get("iscsi_error_state", "")
    )


def yes_no(value) -> str:
    if value is True:
        return "yes"
    if value is False:
        return "no"
    return "unknown"


def duration_seconds(start: str | None, end: str | None):
    if not start or not end:
        return None
    try:
        return int((datetime.fromisoformat(end.replace("Z", "+00:00")) - datetime.fromisoformat(start.replace("Z", "+00:00"))).total_seconds())
    except ValueError:
        return None


def render(attempt_dir: Path) -> Path:
    fio = load(attempt_dir / "fio.json", {})
    attempt = load(attempt_dir / "attempt.json", {})
    states = load(attempt_dir / "state.json", [])
    restoration = load(attempt_dir / "restoration_checks.json", {})
    before = load(attempt_dir / "errors_before.json", {})
    after = load(attempt_dir / "errors_after.json", {})
    if not isinstance(fio.get("jobs"), list) or not fio["jobs"]:
        last_state = states[-1].get("state", "unknown") if states else "unknown"
        lines = [
            f"# Sprint 30 attempt report: {attempt_dir.name}",
            "",
            "## Result",
            "",
            f"- Candidate: `{attempt.get('candidate_id', 'unknown')}`",
            f"- Repetition: `{attempt.get('repetition', 'unknown')}`",
            "- VPU tier: `50 VPUs/GB`",
            f"- Final recorded state: `{last_state}`",
            f"- Started: `{attempt.get('started_at', 'unknown')}`",
            f"- Ended: `{attempt.get('ended_at', 'unknown')}`",
            f"- FIO exit code: `{attempt.get('fio_exit_code', 'unknown')}`",
            "- Performance result: `invalid - fio.json is not valid machine-readable FIO output`",
            "",
            "No performance claim is made for this attempt. The raw output is retained for diagnosis only.",
            "",
            "## Safety and evidence gates",
            "",
            f"- Restoration state: `{attempt.get('restoration_state', 'unknown')}`",
            f"- Restoration checks passed: `{yes_no(restoration.get('restoration_exit_code') == 0 if restoration else None)}`",
            f"- Sentinels valid: `{yes_no(attempt.get('sentinels_valid'))}`",
            f"- Rollback lease disarmed: `{yes_no(not attempt.get('rollback_armed') if 'rollback_armed' in attempt else None)}`",
            "",
            "## Evidence files",
            "",
        ]
        for name in ("fio.json", "fio.log", "iostat.json", "attempt.json", "state.json", "restoration_checks.json", "emergency_restore.json", "errors_before.json", "errors_after.json"):
            if (attempt_dir / name).exists():
                lines.append(f"- [{name}]({name})")
        output = attempt_dir / "attempt_report.md"
        output.write_text("\n".join(lines) + "\n", encoding="ascii")
        return output
    jobs = fio["jobs"]
    data = [job for job in jobs if str(job.get("jobname", "")).startswith("data-8k")]
    redo = [job for job in jobs if str(job.get("jobname", "")).startswith("redo")]
    fra = [job for job in jobs if str(job.get("jobname", "")).startswith("fra-1m")]
    if not data or len(redo) != 1 or len(fra) != 1:
        raise ValueError(f"{attempt_dir}: unexpected FIO job set")

    data_read_iops = sum(number(job.get("read", {}).get("iops")) for job in data)
    data_write_iops = sum(number(job.get("write", {}).get("iops")) for job in data)
    redo_job, fra_job = redo[0], fra[0]
    redo_write_iops = number(redo_job.get("write", {}).get("iops"))
    redo_write_mib = number(redo_job.get("write", {}).get("bw_bytes")) / 1024 / 1024
    fra_mib = sum(number(fra_job.get(direction, {}).get("bw_bytes")) for direction in ("read", "write")) / 1024 / 1024
    cpu = host_cpu(load(attempt_dir / "iostat.json", {}))
    fio_cpu_values = [number(job.get("usr_cpu")) + number(job.get("sys_cpu")) for job in jobs]
    fio_cpu = statistics.fmean(fio_cpu_values) if fio_cpu_values else math.nan
    last_state = states[-1].get("state", "unknown") if states else "unknown"
    start, end = attempt.get("started_at"), attempt.get("ended_at")
    seconds = duration_seconds(start, end)
    clean = monitored_errors_clean(before, after) if before and after else None
    candidate = attempt.get("candidate_id") or attempt_dir.name.rsplit("_", 2)[0]
    repetition = attempt.get("repetition", "unknown")

    lines = [
        f"# Sprint 30 attempt report: {attempt_dir.name}",
        "",
        "## Result",
        "",
        f"- Candidate: `{candidate}`",
        f"- Repetition: `{repetition}`",
        "- VPU tier: `50 VPUs/GB`",
        f"- Final recorded state: `{last_state}`",
        f"- Started: `{start or 'unknown'}`",
        f"- Ended: `{end or 'unknown'}`",
        f"- Measured attempt duration: `{seconds if seconds is not None else 'unknown'} seconds`",
        f"- FIO exit code: `{attempt.get('fio_exit_code', 'unknown')}`",
        "",
        "## Performance summary",
        "",
        "| Metric | Result |",
        "| --- | ---: |",
        f"| DATA read IOPS (all four jobs) | {data_read_iops:.2f} |",
        f"| DATA write IOPS (all four jobs) | {data_write_iops:.2f} |",
        f"| DATA total IOPS | {data_read_iops + data_write_iops:.2f} |",
        f"| REDO write IOPS | {redo_write_iops:.2f} |",
        f"| REDO write throughput (MiB/s) | {redo_write_mib:.2f} |",
        f"| REDO write latency p95 (ms) | {milliseconds(percentile(redo_job, '95'))} |",
        f"| REDO write latency p99 (ms) | {milliseconds(percentile(redo_job, '99'))} |",
        f"| REDO write latency p99.9 (ms) | {milliseconds(percentile(redo_job, '99.9'))} |",
        f"| FRA aggregate throughput (MiB/s) | {fra_mib:.2f} |",
        f"| Host CPU mean (%) | {'n/a' if math.isnan(cpu) else f'{cpu:.2f}'} |",
        f"| Mean FIO process CPU (%) | {'n/a' if math.isnan(fio_cpu) else f'{fio_cpu:.2f}'} |",
        "",
        "## Per-job results",
        "",
        "| Job | Read IOPS | Write IOPS | Read MiB/s | Write MiB/s | Write p99 ms | Write p99.9 ms |",
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]
    for index, job in enumerate(jobs, 1):
        read, write = job.get("read", {}), job.get("write", {})
        lines.append(
            f"| `{job.get('jobname', 'job')}#{index}` | {number(read.get('iops')):.2f} | {number(write.get('iops')):.2f} | "
            f"{number(read.get('bw_bytes')) / 1024 / 1024:.2f} | {number(write.get('bw_bytes')) / 1024 / 1024:.2f} | "
            f"{milliseconds(percentile(job, '99'))} | {milliseconds(percentile(job, '99.9'))} |"
        )
    lines += [
        "",
        "## Safety and evidence gates",
        "",
        f"- Restoration state: `{attempt.get('restoration_state', 'unknown')}`",
        f"- Restoration checks passed: `{yes_no(restoration.get('restoration_exit_code') == 0 if restoration else None)}`",
        f"- Restored controls byte-equal to baseline: `{yes_no(restoration.get('byte_equal') if restoration else None)}`",
        f"- Sentinels valid: `{yes_no(attempt.get('sentinels_valid'))}`",
        f"- Rollback lease disarmed: `{yes_no(not attempt.get('rollback_armed') if 'rollback_armed' in attempt else None)}`",
        f"- Monitored error counters clean: `{yes_no(clean)}`",
        "",
        "This attempt is eligible for aggregate baseline or candidate analysis only when its final state is `passed` and all safety gates above are `yes`.",
        "",
        "## Evidence files",
        "",
    ]
    for name in ("fio.json", "fio.log", "fio_report.html", "iostat.json", "attempt.json", "state.json", "restoration_checks.json", "controls_before.json", "controls_applied.json", "controls_restored.json", "errors_before.json", "errors_after.json", "guest_preflight.json", "oci_preflight.json"):
        if (attempt_dir / name).exists():
            lines.append(f"- [{name}]({name})")
    output = attempt_dir / "attempt_report.md"
    output.write_text("\n".join(lines) + "\n", encoding="ascii")
    return output


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("attempt_dirs", nargs="+", type=Path)
    args = parser.parse_args()
    for directory in args.attempt_dirs:
        print(render(directory.resolve()))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
