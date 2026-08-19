# Sprint 30 attempt report: OFFLOAD_TSO_screening_1

## Result

- Candidate: `OFFLOAD_TSO`
- Repetition: `1`
- VPU tier: `50 VPUs/GB`
- Final recorded state: `passed`
- Started: `2026-08-19T15:38:37Z`
- Ended: `2026-08-19T15:49:39Z`
- Measured attempt duration: `662 seconds`
- FIO exit code: `0`

## Performance summary

| Metric | Result |
| --- | ---: |
| DATA read IOPS (all four jobs) | 44756.46 |
| DATA write IOPS (all four jobs) | 19166.93 |
| DATA total IOPS | 63923.39 |
| REDO write IOPS | 2171.06 |
| REDO write throughput (MiB/s) | 8.48 |
| REDO write latency p95 (ms) | 0.627 |
| REDO write latency p99 (ms) | 0.815 |
| REDO write latency p99.9 (ms) | 1.745 |
| FRA aggregate throughput (MiB/s) | 175.78 |
| Host CPU mean (%) | 39.58 |
| Mean FIO process CPU (%) | 12.57 |

## Per-job results

| Job | Read IOPS | Write IOPS | Read MiB/s | Write MiB/s | Write p99 ms | Write p99.9 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `data-8k#1` | 11186.75 | 4794.36 | 87.40 | 37.46 | 3.260 | 5.276 |
| `data-8k#2` | 11189.10 | 4793.87 | 87.41 | 37.45 | 3.260 | 5.210 |
| `data-8k#3` | 11188.06 | 4789.94 | 87.41 | 37.42 | 3.260 | 5.276 |
| `data-8k#4` | 11192.55 | 4788.76 | 87.44 | 37.41 | 3.260 | 5.276 |
| `redo#5` | 0.00 | 2171.06 | 0.00 | 8.48 | 0.815 | 1.745 |
| `fra-1m#6` | 88.03 | 87.74 | 88.03 | 87.75 | 72.876 | 78.119 |

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
