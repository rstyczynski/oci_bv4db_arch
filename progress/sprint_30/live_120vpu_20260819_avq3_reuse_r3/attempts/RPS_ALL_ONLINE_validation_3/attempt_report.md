# Sprint 30 attempt report: RPS_ALL_ONLINE_validation_3

## Result

- Candidate: `RPS_ALL_ONLINE`
- Repetition: `3`
- VPU tier: `50 VPUs/GB`
- Final recorded state: `passed`
- Started: `2026-08-19T16:01:25Z`
- Ended: `2026-08-19T16:12:27Z`
- Measured attempt duration: `662 seconds`
- FIO exit code: `0`

## Performance summary

| Metric | Result |
| --- | ---: |
| DATA read IOPS (all four jobs) | 45829.08 |
| DATA write IOPS (all four jobs) | 19627.57 |
| DATA total IOPS | 65456.65 |
| REDO write IOPS | 2192.61 |
| REDO write throughput (MiB/s) | 8.56 |
| REDO write latency p95 (ms) | 0.602 |
| REDO write latency p99 (ms) | 0.733 |
| REDO write latency p99.9 (ms) | 1.028 |
| FRA aggregate throughput (MiB/s) | 175.78 |
| Host CPU mean (%) | 39.62 |
| Mean FIO process CPU (%) | 12.78 |

## Per-job results

| Job | Read IOPS | Write IOPS | Read MiB/s | Write MiB/s | Write p99 ms | Write p99.9 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `data-8k#1` | 11455.16 | 4908.61 | 89.49 | 38.35 | 3.129 | 5.210 |
| `data-8k#2` | 11453.52 | 4907.90 | 89.48 | 38.34 | 3.129 | 5.210 |
| `data-8k#3` | 11456.74 | 4906.25 | 89.51 | 38.33 | 3.129 | 5.276 |
| `data-8k#4` | 11463.67 | 4904.81 | 89.56 | 38.32 | 3.129 | 5.210 |
| `redo#5` | 0.00 | 2192.61 | 0.00 | 8.56 | 0.733 | 1.028 |
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
