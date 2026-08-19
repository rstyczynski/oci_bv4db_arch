# Sprint 30 attempt report: REGULAR_BASELINE_INITIAL_baseline_1

## Result

- Candidate: `REGULAR_BASELINE_INITIAL`
- Repetition: `1`
- VPU tier: `50 VPUs/GB`
- Final recorded state: `passed`
- Started: `2026-08-19T13:09:11Z`
- Ended: `2026-08-19T13:20:13Z`
- Measured attempt duration: `662 seconds`
- FIO exit code: `0`

## Performance summary

| Metric | Result |
| --- | ---: |
| DATA read IOPS (all four jobs) | 45753.45 |
| DATA write IOPS (all four jobs) | 19596.46 |
| DATA total IOPS | 65349.91 |
| REDO write IOPS | 2146.44 |
| REDO write throughput (MiB/s) | 8.38 |
| REDO write latency p95 (ms) | 0.627 |
| REDO write latency p99 (ms) | 0.774 |
| REDO write latency p99.9 (ms) | 1.253 |
| FRA aggregate throughput (MiB/s) | 175.78 |
| Host CPU mean (%) | 37.87 |
| Mean FIO process CPU (%) | 12.69 |

## Per-job results

| Job | Read IOPS | Write IOPS | Read MiB/s | Write MiB/s | Write p99 ms | Write p99.9 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `data-8k#1` | 11435.48 | 4900.64 | 89.34 | 38.29 | 2.867 | 4.358 |
| `data-8k#2` | 11439.15 | 4901.84 | 89.37 | 38.30 | 2.867 | 4.293 |
| `data-8k#3` | 11437.88 | 4897.97 | 89.36 | 38.27 | 2.867 | 4.358 |
| `data-8k#4` | 11440.94 | 4896.01 | 89.38 | 38.25 | 2.867 | 4.358 |
| `redo#5` | 0.00 | 2146.44 | 0.00 | 8.38 | 0.774 | 1.253 |
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
