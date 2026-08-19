# Sprint 30 - Test Execution Results

## Final Verdict

Sprint 30 passed its defined integration quality gates. The canonical live
evidence contains the archived five-run baseline, one screening measurement
for each of 13 applicable candidates, both rollback canaries, complete written
and HTML reports, OCI Monitoring windows, and proof that the reusable OCI
infrastructure returned to its captured baseline.

The final recommendation is `REGULAR_BASELINE`: no candidate cleared the
improvement and regression thresholds. This is a valid negative tuning result,
not a failed test.

## Gate Summary

| Gate | Result | Pass rate | Evidence |
| --- | --- | ---: | --- |
| A3 new-code integration | PASS | 10/10 (100%) | `test_run_A3_integration_20260819_final.log` |
| B3 `iscsi_tuning` regression | PASS | 10/10 (100%); component 1/1 | `test_run_B3_integration_20260819_final.log` |
| Independent evidence reconciliation | PASS | 20 indexed rows, 13 testable candidates | `tools/verify_bv_single_path_results.py` |
| Sprint 30 overall | PASS | 100% | canonical run below |

## Canonical Evidence and Reports

Canonical run:

```text
progress/sprint_30/live_50vpu_20260819_avq3_reuse_qd_fix_0910/
```

Primary reports:

- [Sprint summary](live_50vpu_20260819_avq3_reuse_qd_fix_0910/sprint_30_summary.md)
- [FIO analysis](live_50vpu_20260819_avq3_reuse_qd_fix_0910/fio_analysis.md)
- [Aggregate FIO HTML report](live_50vpu_20260819_avq3_reuse_qd_fix_0910/fio_report.html)
- [OCI metrics report](live_50vpu_20260819_avq3_reuse_qd_fix_0910/oci_metrics.md)
- [OCI metrics HTML report](live_50vpu_20260819_avq3_reuse_qd_fix_0910/oci_metrics.html)
- [Machine-readable recommendation](live_50vpu_20260819_avq3_reuse_qd_fix_0910/recommendation.json)
- [Final restored state](live_50vpu_20260819_avq3_reuse_qd_fix_0910/final_state.json)

Every measured attempt has its own `attempt_report.md`, `fio_report.html`, raw
`fio.json`, raw `iostat.json`, topology, error counters, control snapshots, and
restoration proof. For example, the requested iSCSI queue-depth-128 result is:

- [QD128 written report](live_50vpu_20260819_avq3_reuse_qd_fix_0910/attempts/ISCSI_QD128_screening_1/attempt_report.md)
- [QD128 FIO HTML report](live_50vpu_20260819_avq3_reuse_qd_fix_0910/attempts/ISCSI_QD128_screening_1/fio_report.html)

## Test Environment

- OCI CLI profile: `avq3`
- Region: `eu-zurich-1`
- Compute: `VM.Standard.E5.Flex`, 4 OCPUs, 32 GB, x86-64
- Storage: five Block Volumes at 50 VPUs/GB
- Attachment: exactly one iSCSI path per volume; no dm-multipath
- Layout: two-volume DATA stripe, two-volume REDO stripe, direct FRA
- Infrastructure: reused from `progress/sprint_30/reusable_50vpu_avq3`
- Baseline: imported from `progress/sprint_30/live_50vpu_20260818_224723`
- Workload: FIO only; Oracle Database was not installed or invoked

The candidate run did not reprovision infrastructure or remeasure the baseline.
Each candidate restored the captured controls before the next candidate. Final
state records `baseline_equal=true`, `sentinels_valid=true`,
`rollback_armed=false`, `infrastructure_reused=true`, and retained resources.

## Baseline FIO Report

The accepted archived baseline consists of five 600-second FIO measurements.
Each standalone HTML report includes six FIO jobs and nonzero iostat device
throughput.

| Attempt | DATA total IOPS | REDO p99.9 ms | FRA MiB/s | Host CPU mean | Reports |
| --- | ---: | ---: | ---: | ---: | --- |
| Initial 1 | 48018.83 | 1.073 | 93.75 | 34.33% | [written](live_50vpu_20260818_224723/attempts/REGULAR_BASELINE_INITIAL_initial_1/attempt_report.md), [HTML](live_50vpu_20260818_224723/attempts/REGULAR_BASELINE_INITIAL_initial_1/fio_report.html) |
| Initial 2 | 48003.33 | 0.979 | 93.75 | 37.23% | [written](live_50vpu_20260818_224723/attempts/REGULAR_BASELINE_INITIAL_initial_2/attempt_report.md), [HTML](live_50vpu_20260818_224723/attempts/REGULAR_BASELINE_INITIAL_initial_2/fio_report.html) |
| Initial 3 | 47994.11 | 0.913 | 93.75 | 35.39% | [written](live_50vpu_20260818_224723/attempts/REGULAR_BASELINE_INITIAL_initial_3/attempt_report.md), [HTML](live_50vpu_20260818_224723/attempts/REGULAR_BASELINE_INITIAL_initial_3/fio_report.html) |
| Stability extension 4 | 48006.65 | 0.872 | 93.75 | 32.75% | [written](live_50vpu_20260818_224723/attempts/REGULAR_BASELINE_INITIAL_stability_extension_4/attempt_report.md), [HTML](live_50vpu_20260818_224723/attempts/REGULAR_BASELINE_INITIAL_stability_extension_4/fio_report.html) |
| Stability extension 5 | 48005.76 | 0.913 | 93.75 | 33.25% | [written](live_50vpu_20260818_224723/attempts/REGULAR_BASELINE_INITIAL_stability_extension_5/attempt_report.md), [HTML](live_50vpu_20260818_224723/attempts/REGULAR_BASELINE_INITIAL_stability_extension_5/fio_report.html) |

Median baseline values used by the analyzer were 48005.76 DATA IOPS, 0.913 ms
REDO p99.9 latency, and 93.75 MiB/s combined FRA throughput.

## Candidate Results

The following 13 candidates each completed one screening measurement and exact
restoration. None was shortlisted because every candidate failed the approved
performance guardrails, principally REDO p99/p99.9 regression:

`ISCSI_QD128`, `TCP_BUF_2X`, `TCP_BUF_4X`, `TCP_CC_BBR`, `TCP_CC_RENO`,
`NETDEV_BACKLOG_2X`, `NETDEV_BACKLOG_4X`, `RFS_65536`, `RPS_ALL_ONLINE`,
`XPS_BY_QUEUE`, `OFFLOAD_GRO`, `OFFLOAD_GSO`, and `OFFLOAD_TSO`.

QD128 correctly records a requested Open-iSCSI node depth of 128 and a
target-negotiated effective live SCSI depth of 113 on all five targets, up from
the captured effective baseline of 32. Its FIO result was approximately
48002.52 DATA IOPS, 1.516 ms REDO p99.9 latency, 93.75 MiB/s FRA throughput,
and 34.43% host CPU. The latency regression makes it ineligible.

Unsupported, read-only, unsafe, or no-op controls were not silently skipped;
each has a discovered value, disposition, reason, and evidence in
`tunable_coverage.json` and the Sprint summary.

## Test Sequences

Run these from the repository root against the immutable completed evidence.
They do not execute FIO or provision OCI resources:

```bash
export SPRINT30_TEST_OUTPUT_DIR="$PWD/progress/sprint_30/live_50vpu_20260819_avq3_reuse_qd_fix_0910"
export SPRINT30_EXECUTE_LIVE=0
export OCI_CLI_PROFILE=avq3
tests/run.sh --integration --new-only progress/sprint_30/new_tests.manifest
```

Expected result: `Results: 10 passed, 0 failed`.

```bash
export SPRINT30_TEST_OUTPUT_DIR="$PWD/progress/sprint_30/live_50vpu_20260819_avq3_reuse_qd_fix_0910"
export SPRINT30_EXECUTE_LIVE=0
export OCI_CLI_PROFILE=avq3
tests/run.sh --integration --component iscsi_tuning
```

Expected result: the inner suite reports `10 passed, 0 failed` and the
component dispatcher reports `Results: 1 passed, 0 failed`.

## Error and Safety Coverage

IT-1 through IT-4 cover invalid topology, unsupported VPU, duplicate sessions,
multipath evidence, exact binding failures, queue-depth negotiation bounds,
TuneD convergence, rollback unit handling, lease expiry/races, resume proof,
controller exclusion, delayed OCI visibility, and cleanup ownership. IT-5
through IT-10 validate the live topology, archived baseline identity, complete
candidate matrix, both forced rollback canaries, written/HTML/iostat reports,
OCI metric windows, final recommendation, and retained baseline state.

## Historical Failed Attempts

Earlier `live_50vpu_*` directories and A3 logs are retained as diagnostic and
safety-development evidence. They are not pooled into the accepted candidate
comparison. The canonical run and the two `*_final.log` files above supersede
their incomplete gate outcomes.
