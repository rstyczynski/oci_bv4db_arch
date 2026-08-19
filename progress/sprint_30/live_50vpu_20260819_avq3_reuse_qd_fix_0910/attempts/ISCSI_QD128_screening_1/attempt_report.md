# Sprint 30 attempt report: ISCSI_QD128_screening_1

## Result

- Candidate: `ISCSI_QD128`
- Repetition: `1`
- VPU tier: `50 VPUs/GB`
- Final recorded state: `passed`
- Started: `2026-08-19T09:10:02Z`
- Ended: `2026-08-19T09:21:16Z`
- Measured attempt duration: `674 seconds`
- FIO exit code: `0`

## Applied settings

- Requested iSCSI node queue depth: `128`
- Effective live SCSI queue depth: `113`

## Performance summary

| Metric | Result |
| --- | ---: |
| DATA read IOPS (all four jobs) | 33608.79 |
| DATA write IOPS (all four jobs) | 14393.73 |
| DATA total IOPS | 48002.52 |
| REDO write IOPS | 1821.48 |
| REDO write throughput (MiB/s) | 7.12 |
| REDO write latency p95 (ms) | 0.643 |
| REDO write latency p99 (ms) | 0.807 |
| REDO write latency p99.9 (ms) | 1.516 |
| FRA aggregate throughput (MiB/s) | 93.75 |
| Host CPU mean (%) | 34.43 |
| Mean FIO process CPU (%) | 9.74 |

## Per-job results

| Job | Read IOPS | Write IOPS | Read MiB/s | Write MiB/s | Write p99 ms | Write p99.9 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `data-8k#1` | 8397.87 | 3599.70 | 65.61 | 28.12 | 21.103 | 24.248 |
| `data-8k#2` | 8403.25 | 3599.80 | 65.65 | 28.12 | 21.103 | 24.248 |
| `data-8k#3` | 8400.26 | 3596.50 | 65.63 | 28.10 | 21.103 | 24.248 |
| `data-8k#4` | 8407.41 | 3597.73 | 65.68 | 28.11 | 21.103 | 24.248 |
| `redo#5` | 0.00 | 1821.48 | 0.00 | 7.12 | 0.807 | 1.516 |
| `fra-1m#6` | 47.16 | 46.58 | 47.16 | 46.59 | 137.363 | 154.141 |

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
