# Sprint 30 BV4DB-75 - 120-VPU Summary Report

## Verdict

The unchanged Sprint 30 single-path FIO matrix completed on the reused `avq3`
infrastructure with all five volumes at an effective 120 VPUs/GB. All 16 FIO
measurements passed, both rollback canaries proved recovery, and every attempt
restored the captured guest configuration. The independent verifier reconciled
18 indexed rows and all 13 discovered testable candidates.

Recommendation: apply `RPS_ALL_ONLINE` for this 120-VPU, four-OCPU,
single-path workload. Do not apply this result automatically to the separate
50-VPU result or treat it as proof of supported multipath/UHP entitlement.

## Performance Decision

| Measure | 120-VPU baseline | RPS_ALL_ONLINE median (3 runs) | Change |
| --- | ---: | ---: | ---: |
| DATA IOPS | 65,349.91 | 65,028.79 | -0.49% |
| REDO p99 latency | 0.774 ms | 0.733 ms | -5.29% |
| REDO p99.9 latency | 1.253 ms | 1.028 ms | -17.97% |
| FRA combined throughput | 175.78 MiB/s | 175.78 MiB/s | +0.00% |
| Host CPU mean/median | 37.87% | 39.19% | within 10% guard |

`RPS_ALL_ONLINE` was the only eligible and Pareto-optimal candidate. Its three
measurements were stable (DATA CV 0.49%, REDO p99.9 CV 2.11%), error-clean,
within the CPU guard, and introduced no primary regression. The 12 other
candidates were rejected by the approved improvement/regression guardrails.

## Reports and Evidence

- Canonical evidence: `live_120vpu_20260819_avq3_reuse_r3/`
- Aggregate FIO HTML: [fio_report.html](live_120vpu_20260819_avq3_reuse_r3/fio_report.html)
- Detailed FIO analysis: [fio_analysis.md](live_120vpu_20260819_avq3_reuse_r3/fio_analysis.md)
- Run summary: [sprint_30_summary.md](live_120vpu_20260819_avq3_reuse_r3/sprint_30_summary.md)
- OCI Monitoring: [oci_metrics.md](live_120vpu_20260819_avq3_reuse_r3/oci_metrics.md) and [oci_metrics.html](live_120vpu_20260819_avq3_reuse_r3/oci_metrics.html)
- Machine recommendation: [recommendation.json](live_120vpu_20260819_avq3_reuse_r3/recommendation.json)
- Baseline written report: [attempt_report.md](live_120vpu_20260819_avq3_reuse_r3/attempts/REGULAR_BASELINE_INITIAL_baseline_1/attempt_report.md)
- Baseline FIO HTML: [fio_report.html](live_120vpu_20260819_avq3_reuse_r3/attempts/REGULAR_BASELINE_INITIAL_baseline_1/fio_report.html)
- Recommended candidate reports: [screening](live_120vpu_20260819_avq3_reuse_r3/attempts/RPS_ALL_ONLINE_screening_1/fio_report.html), [validation 2](live_120vpu_20260819_avq3_reuse_r3/attempts/RPS_ALL_ONLINE_validation_2/fio_report.html), [validation 3](live_120vpu_20260819_avq3_reuse_r3/attempts/RPS_ALL_ONLINE_validation_3/fio_report.html)

## Resource and Safety Outcome

No compute instance, volume, attachment, filesystem, or benchmark layout was
reprovisioned. The existing volumes were updated in place to 120 VPUs/GB and
live-proven before FIO. Final state records `baseline_equal=true`,
`sentinels_valid=true`, `rollback_armed=false`, and retained resources in the
regular 120-VPU baseline state. Oracle Database was not installed or invoked.

