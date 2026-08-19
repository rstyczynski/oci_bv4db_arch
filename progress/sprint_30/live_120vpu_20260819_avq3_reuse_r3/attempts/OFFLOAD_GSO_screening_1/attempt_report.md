# Sprint 30 attempt report: OFFLOAD_GSO_screening_1

## Result

- Candidate: `OFFLOAD_GSO`
- Repetition: `1`
- VPU tier: `50 VPUs/GB`
- Final recorded state: `passed`
- Started: `2026-08-19T15:27:13Z`
- Ended: `2026-08-19T15:38:14Z`
- Measured attempt duration: `661 seconds`
- FIO exit code: `0`

## Performance summary

| Metric | Result |
| --- | ---: |
| DATA read IOPS (all four jobs) | 46869.83 |
| DATA write IOPS (all four jobs) | 20072.46 |
| DATA total IOPS | 66942.28 |
| REDO write IOPS | 2196.42 |
| REDO write throughput (MiB/s) | 8.58 |
| REDO write latency p95 (ms) | 0.610 |
| REDO write latency p99 (ms) | 0.791 |
| REDO write latency p99.9 (ms) | 1.794 |
| FRA aggregate throughput (MiB/s) | 175.78 |
| Host CPU mean (%) | 39.43 |
| Mean FIO process CPU (%) | 13.15 |

## Per-job results

| Job | Read IOPS | Write IOPS | Read MiB/s | Write MiB/s | Write p99 ms | Write p99.9 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `data-8k#1` | 11718.28 | 5020.70 | 91.55 | 39.22 | 3.064 | 5.276 |
| `data-8k#2` | 11715.57 | 5020.03 | 91.53 | 39.22 | 3.064 | 5.210 |
| `data-8k#3` | 11717.29 | 5016.97 | 91.54 | 39.20 | 3.064 | 5.210 |
| `data-8k#4` | 11718.69 | 5014.76 | 91.55 | 39.18 | 3.064 | 5.276 |
| `redo#5` | 0.00 | 2196.42 | 0.00 | 8.58 | 0.791 | 1.794 |
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
