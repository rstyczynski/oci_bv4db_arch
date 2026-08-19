# Sprint 30 attempt report: RPS_ALL_ONLINE_screening_1

## Result

- Candidate: `RPS_ALL_ONLINE`
- Repetition: `1`
- VPU tier: `50 VPUs/GB`
- Final recorded state: `passed`
- Started: `2026-08-19T14:52:59Z`
- Ended: `2026-08-19T15:04:00Z`
- Measured attempt duration: `661 seconds`
- FIO exit code: `0`

## Performance summary

| Metric | Result |
| --- | ---: |
| DATA read IOPS (all four jobs) | 45528.98 |
| DATA write IOPS (all four jobs) | 19499.81 |
| DATA total IOPS | 65028.79 |
| REDO write IOPS | 2200.25 |
| REDO write throughput (MiB/s) | 8.59 |
| REDO write latency p95 (ms) | 0.602 |
| REDO write latency p99 (ms) | 0.733 |
| REDO write latency p99.9 (ms) | 1.036 |
| FRA aggregate throughput (MiB/s) | 175.78 |
| Host CPU mean (%) | 39.19 |
| Mean FIO process CPU (%) | 12.69 |

## Per-job results

| Job | Read IOPS | Write IOPS | Read MiB/s | Write MiB/s | Write p99 ms | Write p99.9 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `data-8k#1` | 11378.85 | 4876.76 | 88.90 | 38.10 | 3.097 | 5.145 |
| `data-8k#2` | 11383.53 | 4877.48 | 88.93 | 38.11 | 3.097 | 5.145 |
| `data-8k#3` | 11384.37 | 4875.02 | 88.94 | 38.09 | 3.097 | 5.145 |
| `data-8k#4` | 11382.23 | 4870.55 | 88.92 | 38.05 | 3.097 | 5.145 |
| `redo#5` | 0.00 | 2200.25 | 0.00 | 8.59 | 0.733 | 1.036 |
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
