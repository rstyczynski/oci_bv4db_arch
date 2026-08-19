# Sprint 30 attempt report: RPS_ALL_ONLINE_screening_1

## Result

- Candidate: `RPS_ALL_ONLINE`
- Repetition: `1`
- VPU tier: `50 VPUs/GB`
- Final recorded state: `passed`
- Started: `2026-08-19T10:42:29Z`
- Ended: `2026-08-19T10:53:31Z`
- Measured attempt duration: `662 seconds`
- FIO exit code: `0`

## Performance summary

| Metric | Result |
| --- | ---: |
| DATA read IOPS (all four jobs) | 33609.41 |
| DATA write IOPS (all four jobs) | 14393.99 |
| DATA total IOPS | 48003.40 |
| REDO write IOPS | 2211.36 |
| REDO write throughput (MiB/s) | 8.64 |
| REDO write latency p95 (ms) | 0.602 |
| REDO write latency p99 (ms) | 0.733 |
| REDO write latency p99.9 (ms) | 1.155 |
| FRA aggregate throughput (MiB/s) | 93.75 |
| Host CPU mean (%) | 33.48 |
| Mean FIO process CPU (%) | 9.87 |

## Per-job results

| Job | Read IOPS | Write IOPS | Read MiB/s | Write MiB/s | Write p99 ms | Write p99.9 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `data-8k#1` | 8398.34 | 3599.89 | 65.61 | 28.12 | 14.221 | 18.743 |
| `data-8k#2` | 8402.10 | 3599.29 | 65.64 | 28.12 | 14.221 | 19.005 |
| `data-8k#3` | 8398.26 | 3595.63 | 65.61 | 28.09 | 14.352 | 19.005 |
| `data-8k#4` | 8410.71 | 3599.18 | 65.71 | 28.12 | 14.352 | 19.005 |
| `redo#5` | 0.00 | 2211.36 | 0.00 | 8.64 | 0.733 | 1.155 |
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
