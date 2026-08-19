# Sprint 30 attempt report: TCP_CC_RENO_screening_1

## Result

- Candidate: `TCP_CC_RENO`
- Repetition: `1`
- VPU tier: `50 VPUs/GB`
- Final recorded state: `passed`
- Started: `2026-08-19T14:07:00Z`
- Ended: `2026-08-19T14:18:13Z`
- Measured attempt duration: `673 seconds`
- FIO exit code: `0`

## Performance summary

| Metric | Result |
| --- | ---: |
| DATA read IOPS (all four jobs) | 45358.77 |
| DATA write IOPS (all four jobs) | 19426.06 |
| DATA total IOPS | 64784.83 |
| REDO write IOPS | 2043.84 |
| REDO write throughput (MiB/s) | 7.98 |
| REDO write latency p95 (ms) | 0.676 |
| REDO write latency p99 (ms) | 0.897 |
| REDO write latency p99.9 (ms) | 2.056 |
| FRA aggregate throughput (MiB/s) | 175.78 |
| Host CPU mean (%) | 39.32 |
| Mean FIO process CPU (%) | 12.66 |

## Per-job results

| Job | Read IOPS | Write IOPS | Read MiB/s | Write MiB/s | Write p99 ms | Write p99.9 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `data-8k#1` | 11336.40 | 4858.40 | 88.57 | 37.96 | 3.293 | 5.538 |
| `data-8k#2` | 11337.71 | 4857.82 | 88.58 | 37.95 | 3.293 | 5.472 |
| `data-8k#3` | 11341.55 | 4856.54 | 88.61 | 37.94 | 3.293 | 5.538 |
| `data-8k#4` | 11343.10 | 4853.31 | 88.62 | 37.92 | 3.293 | 5.472 |
| `redo#5` | 0.00 | 2043.84 | 0.00 | 7.98 | 0.897 | 2.056 |
| `fra-1m#6` | 88.04 | 87.73 | 88.04 | 87.74 | 72.876 | 79.167 |

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
