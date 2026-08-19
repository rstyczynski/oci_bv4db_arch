# Sprint 30 attempt report: XPS_BY_QUEUE_screening_1

## Result

- Candidate: `XPS_BY_QUEUE`
- Repetition: `1`
- VPU tier: `50 VPUs/GB`
- Final recorded state: `passed`
- Started: `2026-08-19T15:04:23Z`
- Ended: `2026-08-19T15:15:24Z`
- Measured attempt duration: `661 seconds`
- FIO exit code: `0`

## Performance summary

| Metric | Result |
| --- | ---: |
| DATA read IOPS (all four jobs) | 45512.74 |
| DATA write IOPS (all four jobs) | 19492.65 |
| DATA total IOPS | 65005.40 |
| REDO write IOPS | 2213.47 |
| REDO write throughput (MiB/s) | 8.65 |
| REDO write latency p95 (ms) | 0.602 |
| REDO write latency p99 (ms) | 0.741 |
| REDO write latency p99.9 (ms) | 1.253 |
| FRA aggregate throughput (MiB/s) | 175.78 |
| Host CPU mean (%) | 38.68 |
| Mean FIO process CPU (%) | 12.68 |

## Per-job results

| Job | Read IOPS | Write IOPS | Read MiB/s | Write MiB/s | Write p99 ms | Write p99.9 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `data-8k#1` | 11372.74 | 4874.12 | 88.85 | 38.08 | 2.966 | 4.817 |
| `data-8k#2` | 11375.39 | 4873.88 | 88.87 | 38.08 | 2.998 | 4.817 |
| `data-8k#3` | 11382.88 | 4874.33 | 88.93 | 38.08 | 2.966 | 4.817 |
| `data-8k#4` | 11381.73 | 4870.33 | 88.92 | 38.05 | 2.966 | 4.817 |
| `redo#5` | 0.00 | 2213.47 | 0.00 | 8.65 | 0.741 | 1.253 |
| `fra-1m#6` | 88.03 | 87.73 | 88.03 | 87.75 | 72.876 | 78.119 |

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
