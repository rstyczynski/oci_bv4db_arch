# Sprint 30 attempt report: OFFLOAD_TSO_screening_1

## Result

- Candidate: `OFFLOAD_TSO`
- Repetition: `1`
- VPU tier: `50 VPUs/GB`
- Final recorded state: `passed`
- Started: `2026-08-19T11:28:07Z`
- Ended: `2026-08-19T11:39:08Z`
- Measured attempt duration: `661 seconds`
- FIO exit code: `0`

## Performance summary

| Metric | Result |
| --- | ---: |
| DATA read IOPS (all four jobs) | 33609.40 |
| DATA write IOPS (all four jobs) | 14393.95 |
| DATA total IOPS | 48003.36 |
| REDO write IOPS | 2208.97 |
| REDO write throughput (MiB/s) | 8.63 |
| REDO write latency p95 (ms) | 0.602 |
| REDO write latency p99 (ms) | 0.733 |
| REDO write latency p99.9 (ms) | 1.020 |
| FRA aggregate throughput (MiB/s) | 93.75 |
| Host CPU mean (%) | 32.42 |
| Mean FIO process CPU (%) | 9.66 |

## Per-job results

| Job | Read IOPS | Write IOPS | Read MiB/s | Write MiB/s | Write p99 ms | Write p99.9 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `data-8k#1` | 8398.20 | 3599.83 | 65.61 | 28.12 | 14.090 | 18.743 |
| `data-8k#2` | 8399.06 | 3597.97 | 65.62 | 28.11 | 14.221 | 18.743 |
| `data-8k#3` | 8402.72 | 3597.48 | 65.65 | 28.11 | 14.090 | 18.743 |
| `data-8k#4` | 8409.43 | 3598.66 | 65.70 | 28.11 | 14.221 | 18.743 |
| `redo#5` | 0.00 | 2208.97 | 0.00 | 8.63 | 0.733 | 1.020 |
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
