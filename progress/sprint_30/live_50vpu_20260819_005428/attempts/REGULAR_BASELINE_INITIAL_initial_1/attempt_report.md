# Sprint 30 attempt report: REGULAR_BASELINE_INITIAL_initial_1

## Result

- Candidate: `REGULAR_BASELINE_INITIAL`
- Repetition: `1`
- VPU tier: `50 VPUs/GB`
- Final recorded state: `passed`
- Started: `2026-08-19T01:00:57Z`
- Ended: `2026-08-19T01:16:37Z`
- Measured attempt duration: `940 seconds`
- FIO exit code: `0`

## Performance summary

| Metric | Result |
| --- | ---: |
| DATA read IOPS (all four jobs) | 33615.05 |
| DATA write IOPS (all four jobs) | 14396.47 |
| DATA total IOPS | 48011.51 |
| REDO write IOPS | 767.19 |
| REDO write throughput (MiB/s) | 3.00 |
| REDO write latency p95 (ms) | 0.553 |
| REDO write latency p99 (ms) | 0.692 |
| REDO write latency p99.9 (ms) | 1.155 |
| FRA aggregate throughput (MiB/s) | 93.75 |
| Host CPU mean (%) | 35.10 |
| Mean FIO process CPU (%) | 9.57 |

## Per-job results

| Job | Read IOPS | Write IOPS | Read MiB/s | Write MiB/s | Write p99 ms | Write p99.9 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `data-8k#1` | 8398.58 | 3599.97 | 65.61 | 28.12 | 15.008 | 19.530 |
| `data-8k#2` | 8396.87 | 3597.05 | 65.60 | 28.10 | 15.139 | 19.792 |
| `data-8k#3` | 8408.49 | 3599.98 | 65.69 | 28.12 | 15.008 | 19.530 |
| `data-8k#4` | 8411.10 | 3599.46 | 65.71 | 28.12 | 15.008 | 19.530 |
| `redo#5` | 0.00 | 767.19 | 0.00 | 3.00 | 0.692 | 1.155 |
| `fra-1m#6` | 47.16 | 46.58 | 47.16 | 46.59 | 137.363 | 149.946 |

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
