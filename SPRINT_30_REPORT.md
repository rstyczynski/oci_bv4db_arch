# Sprint 30 Final Report

Status: **complete**  
Backlog items: **BV4DB-72**, **BV4DB-75**  
Execution date: **2026-08-18 to 2026-08-19**

## Executive Finding

Sprint 30 measured the approved, unchanged Oracle-style FIO workload on one
reused four-OCPU OCI compute instance with five single-path iSCSI Block
Volumes. It evaluated the same 13 safe and applicable Linux/iSCSI/network
tuning candidates at 50 and 120 VPUs/GB.

- At **50 VPUs/GB**, no candidate passed the performance guardrails. Keep
  `REGULAR_BASELINE`.
- At **120 VPUs/GB**, `RPS_ALL_ONLINE` was the only eligible and
  Pareto-optimal candidate. It improved REDO tail latency without a primary
  throughput regression and is the recommendation for this exact tested
  configuration.

These are tier-specific findings. The 120-VPU recommendation does not replace
the 50-VPU result and is not proof of multipath or general UHP entitlement.

## Performance Findings

| Configuration | DATA IOPS | REDO p99.9 | FRA throughput | Decision |
| --- | ---: | ---: | ---: | --- |
| 50-VPU baseline | 48,005.76 | 0.913 ms | 93.75 MiB/s | Retain baseline |
| 120-VPU baseline | 65,349.91 | 1.253 ms | 175.78 MiB/s | Comparison baseline |
| 120-VPU `RPS_ALL_ONLINE`, median of 3 runs | 65,028.79 | 1.028 ms | 175.78 MiB/s | Recommended |

For `RPS_ALL_ONLINE` at 120 VPUs/GB:

- DATA IOPS changed by **-0.49%**;
- REDO p99 improved by **5.29%**;
- REDO p99.9 improved by **17.97%**;
- FRA throughput was unchanged;
- host CPU remained within the 10% guard;
- the three measurements were stable and error-clean.

All other tested 120-VPU candidates failed at least one approved improvement,
regression, stability, CPU, or error guard and are not recommended.

## Test and Safety Outcome

- The 50-VPU canonical evidence reconciles 20 indexed rows and 13 testable
  candidates.
- The 120-VPU extension reconciles 18 indexed rows: 16 successful FIO
  measurements and two expected-failure rollback canaries.
- The 120-VPU A3 integration gate passed 10/10 tests.
- The scoped B3 regression gate passed 10/10 tests and its component
  dispatcher passed 1/1.
- No test or FIO job was changed for the 120-VPU extension.
- Existing compute, volumes, attachments, filesystems, and benchmark data were
  reused. No per-test provisioning or baseline collection was performed.
- Every tuning attempt restored the captured guest configuration. Final state
  proved byte-equal baseline restoration, valid sentinels, disarmed rollback,
  and retained OCI resources at 120 VPUs/GB.
- Oracle Database was not installed or invoked; this was an FIO-based
  single-path characterization.

## Reports and Evidence

### 120-VPU result

- [120-VPU written summary](progress/sprint_30/sprint_30_120vpu_summary.md)
- [120-VPU aggregate FIO HTML](progress/sprint_30/live_120vpu_20260819_avq3_reuse_r3/fio_report.html)
- [120-VPU detailed FIO analysis](progress/sprint_30/live_120vpu_20260819_avq3_reuse_r3/fio_analysis.md)
- [120-VPU OCI Monitoring report](progress/sprint_30/live_120vpu_20260819_avq3_reuse_r3/oci_metrics.md)
- [120-VPU machine-readable recommendation](progress/sprint_30/live_120vpu_20260819_avq3_reuse_r3/recommendation.json)

### 50-VPU result

- [Sprint 30 test and baseline report](progress/sprint_30/sprint_30_tests.md)
- [50-VPU aggregate FIO HTML](progress/sprint_30/live_50vpu_20260819_avq3_reuse_qd_fix_0910/fio_report.html)
- [50-VPU detailed FIO analysis](progress/sprint_30/live_50vpu_20260819_avq3_reuse_qd_fix_0910/fio_analysis.md)
- [50-VPU OCI Monitoring report](progress/sprint_30/live_50vpu_20260819_avq3_reuse_qd_fix_0910/oci_metrics.md)

## Scope and Use

Apply `RPS_ALL_ONLINE` only to a configuration matching the 120-VPU evidence:
`VM.Standard.E5.Flex`, four OCPUs, five volumes, one iSCSI path per volume, and
the tested DATA/REDO/FRA FIO workload. Revalidate before applying it to a
different shape, OCPU count, storage topology, multipath setup, workload, or
production Oracle Database environment.
