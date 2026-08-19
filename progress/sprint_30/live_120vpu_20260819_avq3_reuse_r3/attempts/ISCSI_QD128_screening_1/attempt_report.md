# Sprint 30 attempt report: ISCSI_QD128_screening_1

## Result

- Candidate: `ISCSI_QD128`
- Repetition: `1`
- VPU tier: `50 VPUs/GB`
- Final recorded state: `passed`
- Started: `2026-08-19T13:20:37Z`
- Ended: `2026-08-19T13:31:50Z`
- Measured attempt duration: `673 seconds`
- FIO exit code: `0`

## Applied settings

- Requested iSCSI node queue depth: `128`
- Effective live SCSI queue depth: `113`

## Performance summary

| Metric | Result |
| --- | ---: |
| DATA read IOPS (all four jobs) | 48679.83 |
| DATA write IOPS (all four jobs) | 20850.48 |
| DATA total IOPS | 69530.31 |
| REDO write IOPS | 1987.03 |
| REDO write throughput (MiB/s) | 7.76 |
| REDO write latency p95 (ms) | 0.700 |
| REDO write latency p99 (ms) | 0.946 |
| REDO write latency p99.9 (ms) | 2.933 |
| FRA aggregate throughput (MiB/s) | 175.78 |
| Host CPU mean (%) | 40.15 |
| Mean FIO process CPU (%) | 13.01 |

## Per-job results

| Job | Read IOPS | Write IOPS | Read MiB/s | Write MiB/s | Write p99 ms | Write p99.9 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `data-8k#1` | 12167.58 | 5212.46 | 95.06 | 40.72 | 3.326 | 5.472 |
| `data-8k#2` | 12170.19 | 5215.61 | 95.08 | 40.75 | 3.326 | 5.472 |
| `data-8k#3` | 12169.80 | 5213.26 | 95.08 | 40.73 | 3.326 | 5.472 |
| `data-8k#4` | 12172.25 | 5209.15 | 95.10 | 40.70 | 3.326 | 5.472 |
| `redo#5` | 0.00 | 1987.03 | 0.00 | 7.76 | 0.946 | 2.933 |
| `fra-1m#6` | 88.05 | 87.72 | 88.05 | 87.73 | 72.876 | 78.119 |

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
