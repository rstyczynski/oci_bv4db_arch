# Sprint 30 attempt report: RPS_ALL_ONLINE_validation_2

## Result

- Candidate: `RPS_ALL_ONLINE`
- Repetition: `2`
- VPU tier: `50 VPUs/GB`
- Final recorded state: `passed`
- Started: `2026-08-19T15:50:02Z`
- Ended: `2026-08-19T16:01:03Z`
- Measured attempt duration: `661 seconds`
- FIO exit code: `0`

## Performance summary

| Metric | Result |
| --- | ---: |
| DATA read IOPS (all four jobs) | 45283.43 |
| DATA write IOPS (all four jobs) | 19393.31 |
| DATA total IOPS | 64676.74 |
| REDO write IOPS | 2188.03 |
| REDO write throughput (MiB/s) | 8.55 |
| REDO write latency p95 (ms) | 0.610 |
| REDO write latency p99 (ms) | 0.733 |
| REDO write latency p99.9 (ms) | 0.987 |
| FRA aggregate throughput (MiB/s) | 175.78 |
| Host CPU mean (%) | 38.82 |
| Mean FIO process CPU (%) | 12.60 |

## Per-job results

| Job | Read IOPS | Write IOPS | Read MiB/s | Write MiB/s | Write p99 ms | Write p99.9 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `data-8k#1` | 11320.61 | 4851.64 | 88.44 | 37.90 | 2.998 | 4.948 |
| `data-8k#2` | 11319.21 | 4849.66 | 88.43 | 37.89 | 2.998 | 4.948 |
| `data-8k#3` | 11318.41 | 4846.54 | 88.43 | 37.86 | 2.998 | 4.948 |
| `data-8k#4` | 11325.19 | 4845.47 | 88.48 | 37.86 | 2.998 | 4.948 |
| `redo#5` | 0.00 | 2188.03 | 0.00 | 8.55 | 0.733 | 0.987 |
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
