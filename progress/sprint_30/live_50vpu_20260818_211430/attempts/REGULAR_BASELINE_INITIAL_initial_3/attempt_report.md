# Sprint 30 attempt report: REGULAR_BASELINE_INITIAL_initial_3

## Result

- Candidate: `REGULAR_BASELINE_INITIAL`
- Repetition: `3`
- VPU tier: `50 VPUs/GB`
- Final recorded state: `passed`
- Started: `2026-08-18T21:48:36Z`
- Ended: `2026-08-18T21:59:37Z`
- Measured attempt duration: `661 seconds`
- FIO exit code: `0`

## Performance summary

| Metric | Result |
| --- | ---: |
| DATA read IOPS (all four jobs) | 33608.64 |
| DATA write IOPS (all four jobs) | 14393.61 |
| DATA total IOPS | 48002.24 |
| REDO write IOPS | 1623.53 |
| REDO write throughput (MiB/s) | 6.34 |
| REDO write latency p95 (ms) | 0.578 |
| REDO write latency p99 (ms) | 0.725 |
| REDO write latency p99.9 (ms) | 1.188 |
| FRA aggregate throughput (MiB/s) | 93.75 |
| Host CPU mean (%) | 36.09 |
| Mean FIO process CPU (%) | 9.98 |

## Per-job results

| Job | Read IOPS | Write IOPS | Read MiB/s | Write MiB/s | Write p99 ms | Write p99.9 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `data-8k#1` | 8397.12 | 3599.33 | 65.60 | 28.12 | 15.532 | 19.792 |
| `data-8k#2` | 8401.69 | 3599.10 | 65.64 | 28.12 | 15.532 | 20.054 |
| `data-8k#3` | 8403.17 | 3597.75 | 65.65 | 28.11 | 15.532 | 19.792 |
| `data-8k#4` | 8406.67 | 3597.42 | 65.68 | 28.10 | 15.532 | 19.792 |
| `redo#5` | 0.00 | 1623.53 | 0.00 | 6.34 | 0.725 | 1.188 |
| `fra-1m#6` | 47.16 | 46.58 | 47.16 | 46.59 | 137.363 | 145.752 |

## Safety and evidence gates

- Restoration state: `restored`
- Restoration checks passed: `yes`
- Restored controls byte-equal to baseline: `yes`
- Sentinels valid: `yes`
- Rollback lease disarmed: `yes`
- Monitored error counters clean: `yes`

This attempt is eligible for aggregate baseline or candidate analysis only when its final state is `passed` and all safety gates above are `yes`.

## Evidence files

- [fio.json](fio.json)
- [fio.log](fio.log)
- [fio_report.html](fio_report.html)
- [iostat.json](iostat.json)
- [attempt.json](attempt.json)
- [state.json](state.json)
- [restoration_checks.json](restoration_checks.json)
- [controls_before.json](controls_before.json)
- [controls_applied.json](controls_applied.json)
- [controls_restored.json](controls_restored.json)
- [errors_before.json](errors_before.json)
- [errors_after.json](errors_after.json)
- [guest_preflight.json](guest_preflight.json)
- [oci_preflight.json](oci_preflight.json)
