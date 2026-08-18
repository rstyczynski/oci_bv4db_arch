# Sprint 30 - Design

## BV4DB-72. Tune single-path iSCSI performance on a four-OCPU midrange server

Status: Accepted

### Requirement Summary

Measure and recommend the best supported iSCSI network-path configuration at exactly 50 VPUs/GB for a four-OCPU midrange OCI server using the project’s established Oracle-style block-volume layout for FIO file placement. This is a FIO-only sprint: it must not install Oracle Database or execute database workloads. The target attachment remains single-path; this sprint must not enable or evaluate dm-multipath as a tuning variant.

### Feasibility Analysis

OCI documents an iSCSI queue-depth change through `iscsiadm`, while Oracle Linux and the Linux kernel document TCP buffers, backlog, congestion control, RPS/RFS/XPS, NIC controls, and TuneD profiles. Actual availability varies by image, kernel, and driver, so “all possible tunables” means every control discovered on the pinned Sprint 30 host is either tested or recorded in the coverage ledger as read-only, unsupported, unsafe, or not applicable with an evidence-backed reason.

OCI classifies 30–120 VPUs/GB as Ultra High Performance and documents at least 16 OCPUs for multipath support on VM shapes. That requirement does not prohibit requesting 50 VPUs/GB for a volume observed through one path on a four-OCPU VM. Sprint 30 is therefore an intentional 50-VPU characterization outside the supported multipath/UHP performance path. Live observation showed that OCI persistently returns the present-but-null pair `is-multipath=null` and `multipath-devices=null` when a single-path iSCSI attachment is explicitly requested on this ineligible four-OCPU shape. The accepted proof is consequently conjunctive: scaffold input requests `is_multipath=false`; the attachment is exactly bound iSCSI with one primary endpoint; `is-multipath` is false or present-but-null, never true; `multipath-devices` is an empty array or present-but-null, never nonempty; and guest evidence proves exactly one live session, no multipath device, unique persistent identity, and the expected route before formatting or FIO. The prior 45-VPU OCI rejection is retained as feasibility evidence; if OCI rejects 50 VPUs/GB, reports a different effective value, exposes a secondary path, or enables multipath, Sprint 30 fails feasibility and no FIO result is claimed. Revalidation at 30 and 120 VPUs/GB belongs exclusively to future backlog items BV4DB-74 and BV4DB-75.

Sources:

- https://docs.oracle.com/en-us/iaas/Content/Block/Concepts/blockvolumehigherperformance.htm
- https://docs.oracle.com/en-us/iaas/Content/Block/Concepts/blockvolumeperformance.htm
- https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/configuringmultipathattachments.htm
- https://docs.oracle.com/en/operating-systems/oracle-linux/10/tuned/reviewing_tuned_profiles.html
- https://docs.oracle.com/en-us/iaas/Content/Compute/References/computeshapes.htm
- https://docs.kernel.org/networking/scaling.html

### Fixed Compute and Image Baseline

| Property | Sprint 30 value | Verification |
| --- | --- | --- |
| Shape | `VM.Standard.E5.Flex` | OCI instance metadata and Terraform/OCI state |
| Compute | exactly 4 OCPUs and 32 GB RAM | OCI shape configuration |
| Architecture | x86_64 | `uname -m` and `lscpu` |
| Guest CPUs | discovered, not assumed; four x86 OCPUs normally expose eight vCPUs | `lscpu`, `nproc`, and `/sys/devices/system/cpu/online` |
| Image | current Oracle Linux 9 platform image, resolved once before provisioning and pinned by image OCID for the entire matrix | archived image OCID, display name, OS version, kernel, and UEK/RHCK identity |
| Network interface | interface returned by `ip route get` for every iSCSI portal; all portals must resolve to the same interface | archived route, address, driver, queue, IRQ, RSS, and link evidence |

RPS/XPS masks and NIC channel limits are derived from the online Linux vCPU and queue topology. They must never be hard-coded from the OCPU count. A different image OCID, kernel, shape, memory size, CPU topology, or iSCSI-facing interface starts a different experiment and cannot be merged into the Sprint 30 comparison.

### Fixed 50-VPU Baseline

Every Sprint 30 tuning candidate is compared only with the regular OCI/guest-settings baseline at 50 VPUs/GB. All five volumes remain at that value for the entire experiment. The pinned image, compute topology, single-path attachments, volume sizes, filesystems, FIO profile, and collection window remain fixed.

| VPUs/GB | Attachment | Baseline action | Interpretation |
| --- | --- | --- | --- |
| 50 | single-path iSCSI | Run FIO with unchanged OCI and guest settings. | Characterize the 50-VPU volume configuration through the constrained four-OCPU, single-path host. |

Sprint 30 performs no 30-, 45-, or 120-VPU run and no VPU transition experiment. An attempt, plan entry, index row, report row, or recommendation containing any value other than 50 fails the Sprint 30 gate.

### Block-Volume Layout

Sprint 30 reuses the five-volume Oracle-style topology introduced by Sprint 4 and validated by Sprints 5, 9, and 10. It preserves the established capacity, device-path, LVM, filesystem, and mount layout while deliberately connecting exactly one iSCSI path per volume.

Project sources of truth are `progress/sprint_4/sprint_4_design.md` for the topology and striping rationale, `tools/run_bv_fio_oracle.sh` for the implemented volume/LVM defaults, and `progress/sprint_10/oracle-layout-4k-redo.fio` for workload file placement.

| Role | OCI volumes | Size each | Consistent paths | Guest layout | Filesystem and mount |
| --- | ---: | ---: | --- | --- | --- |
| DATA | 2 | 200 GB | `/dev/oracleoci/oraclevdb`, `/dev/oracleoci/oraclevdc` | PVs in `vg_data`; `lv_oradata` uses all free extents, two stripes, 256 KiB stripe size | ext4 created with `nodiscard`; `/u02/oradata` |
| REDO | 2 | 50 GB | `/dev/oracleoci/oraclevdd`, `/dev/oracleoci/oraclevde` | PVs in `vg_redo`; `lv_redo` uses all free extents, two stripes, 256 KiB stripe size | ext4 created with `nodiscard`; `/u03/redo` |
| FRA | 1 | 100 GB | `/dev/oracleoci/oraclevdf` | direct whole-volume filesystem; no LVM stripe | ext4 created with `nodiscard`; `/u04/fra` |

The benchmark runner must verify that each consistent path resolves to a distinct attached block volume, exactly one iSCSI session exists for each target, no device resolves through dm-multipath, both LVM logical volumes have two stripes with a 256 KiB stripe size, and all three filesystems are mounted before FIO starts.

The boot volume is explicitly out of scope. It must not be an FIO file target,
an LVM PV, a filesystem initialization target, an iSCSI tuning target, or a
candidate evidence device. All load generation and storage-layout actions are
restricted to the five separately attached Block Volumes listed above.

Provision all five volumes at 50 VPUs/GB and keep them at that value. Wait until every volume leaves the provisioning state, confirm the effective value of 50 from OCI, revalidate the conjunctive single-path proof above, one session per target, unchanged device identity, LVM, filesystem, sentinels, and mounts, and only then run FIO. Repeat the effective-value and path checks before every measured run so a mixed, drifted, or multipath DATA/REDO/FRA tier cannot confound the comparison.

Layout initialization is allowed only on newly provisioned, empty Sprint 30 volumes. A rerun must discover and reuse the existing PV, VG, LV, filesystem, and mount metadata; it must never use a failed discovery check as permission to run `wipefs`, `pvcreate`, `mkfs`, or other initialization commands.

### Design Overview

The sprint adds one resumable benchmark runner and report renderer. The runner provisions the fixed topology once, captures an immutable baseline, applies exactly one reversible candidate or documented coupled profile, executes the fixed-50-VPU candidate/repetition schedule, restores and verifies baseline state, and then advances. It records raw FIO, CPU, iSCSI, TCP/network, block-device, OCI, integrity, and kernel-counter evidence for every attempt.

### OCI Resource Lifecycle

All OCI resource creation, adoption, attachment, state recording, and teardown
must use the repository's `oci_scaffold` tool. Sprint 30's runner sources
`oci_scaffold/do/oci_scaffold.sh`, uses `ensure-compute.sh` for the pinned
four-OCPU target, uses one `ensure-blockvolume.sh` state file per DATA/REDO/FRA
volume, and uses the scaffold teardown path for resources it owns. It must not
replace this lifecycle with ad-hoc `oci compute instance launch`, `oci bv volume
create`, or attachment commands.

The runner stores its scaffold state below its own output directory, records
whether every compute/volume/attachment was created or adopted, and passes
`bv_is_multipath=false` for every iSCSI attachment. A pre-existing resource may
be adopted only after its OCID, exact 50-VPU setting, size, target instance,
single-path attachment state, and ownership/teardown decision are archived.
The boot volume is never placed in a Sprint 30 scaffold state and is never a
teardown, layout, or tuning target.

The candidate catalogue must inspect and classify the target’s available controls before execution:

| Category | Proposed parameters to test | Safety boundary |
| --- | --- | --- |
| iSCSI session | `ISCSI_QD128`: set `node.session.queue_depth=128` on all five target/portal records | Use only `iscsiadm`; activate through the safe reconnect sequence and prove the live value from session detail/sysfs. |
| TCP socket buffers | `TCP_BUF_2X` and `TCP_BUF_4X`: multiply the discovered numeric baseline for `net.core.rmem_max` and `net.core.wmem_max`; multiply only the maximum field of `net.ipv4.tcp_rmem` and `net.ipv4.tcp_wmem`, retaining discovered minimum/default fields | Candidate value is exactly baseline × multiplier; exclude overflow or kernel-rejected values and verify readback. |
| TCP congestion control | one `TCP_CC_<name>` candidate for every alternative already listed in `net.ipv4.tcp_available_congestion_control` | Do not load a new module; reconnect sessions and verify the algorithm on actual iSCSI sockets with `ss -ti`. |
| receive backlog | `NETDEV_BACKLOG_2X` and `NETDEV_BACKLOG_4X`: multiply discovered `net.core.netdev_max_backlog` | Exclude overflow or rejected values and verify readback. |
| RPS/RFS/XPS | `RPS_ALL_ONLINE`: all online vCPUs; `RFS_65536`: global 65536 entries divided evenly among RX queues when baseline RPS is already active; `RPS_RFS_65536`: the documented coupled RPS-all-online plus RFS setting when baseline RPS masks are zero; `XPS_BY_QUEUE`: deterministic online-vCPU masks distributed across TX queues | Generate masks from discovered online vCPUs and queues; record every per-queue file before/apply/restore. Never benchmark standalone RFS with zero RPS masks as a no-op. |
| NIC rings | `NIC_RING_MAX`: driver-advertised maximum RX and TX ring sizes | Exclude fixed/unsupported rings; verify `ethtool -g` readback. |
| NIC channels | `NIC_CHANNEL_MAX`: combined channels set to the smaller of the driver maximum and online-vCPU count | Exclude unsupported channels; verify queue count and IRQ topology after application. |
| NIC coalescing | `NIC_COAL_ADAPTIVE_ON` and `NIC_COAL_ADAPTIVE_OFF` when adaptive RX/TX is changeable | Toggle only supported fields and verify exact `ethtool -c` state. |
| NIC offloads | one candidate that inverts the baseline for each individually changeable GRO, GSO, TSO, RX-checksum, and TX-checksum feature | Never combine offload candidates; verify `ethtool -k` and restore before the next candidate. |
| MTU | inventory only; create `MTU_<value>` only when OCI documentation and both endpoints identify the same supported alternative | Otherwise mark excluded/unsafe in the ledger; never infer endpoint support. |
| TuneD profiles | one candidate for each installed applicable profile among `throughput-performance`, `network-throughput`, and discovered OCI profiles such as RPS/XPS, busy-polling, or OCI-NIC profiles | Treat a profile as a coupled setting group; archive its full settings delta and restore the original active profile. |

The runner must write a machine-readable `tunable_coverage.json` before changing the host and update it atomically after each attempt. Every discovered control has a stable candidate ID, a planning `disposition` of `testable`, `read_only`, `unsupported`, `unsafe`, or `not_applicable`, and the discovered value, proposed value, evidence path, and reason. Every `testable` entry separately has an `execution_status` of `pending`, `tested`, `inconclusive`, or `failed`; it begins `pending` and may change only from archived attempt and restoration evidence. Excluded dispositions require an evidence-backed reason and have no execution status. Sprint closure requires no pending testable entry and exact reconciliation of every tested, inconclusive, or failed entry to its attempts and restoration proof. A missing or fixed control is never silently skipped or forced.

### Runner and State Interface

The implementation entry point is `tools/oci_bv_single_path_tuning.sh`. It supports `--plan`, `--execute`, `--resume <run-id>`, singular `--vpu <integer>`, `--repeats 3`, `--keep-infra`, and `--output-dir`. Sprint closure always requires the complete discovered candidate matrix; the earlier partial `--candidate` interface was removed because it could not produce a schema-valid completed coverage ledger. Defaults are plan-only, all candidates, 50 VPUs/GB, three measured repetitions, teardown after successful evidence copy, and a timestamped Sprint 30 output directory. The singular VPU argument keeps the method reusable, but the Sprint 30 plan profile is locked to 50: its gate rejects a different input or any non-50 plan, attempt, index, report, or recommendation value. BV4DB-74 and BV4DB-75 must approve their own plans before using the interface at 30 or 120.

OCI profile/region, compartment, subnet, pinned image OCID, and SSH/Run Command prerequisites are explicit inputs; secrets are never written to artifacts. Each run owns `run_state.json`, `tunable_coverage.json`, `experiment_plan.json`, `results_index.json`, and per-attempt evidence directories. State transitions are atomic and record planned, applying, active, measuring, restoring, restored, passed, failed, or interrupted. `--resume` may continue only after it proves baseline configuration, sentinels, topology, and attachments; otherwise it fails closed.

### FIO Load Generation

Sprint 30 reuses the project’s Sprint 10 Oracle-layout FIO profile without installing Oracle Database. Every 50-VPU baseline and candidate run uses `ioengine=libaio`, `direct=1`, `time_based=1`, `runtime=600`, `ramp_time=60`, `group_reporting=0`, `invalidate=1`, `lat_percentiles=1`, `percentile_list=95:99:99.9`, and `--output-format=json`.

| FIO job | File-placement role | Parameters |
| --- | --- | --- |
| `data-8k` | DATA layout filesystem | `randrw`, 70% read, `bs=8k`, `size=32G`, `numjobs=4`, `iodepth=16` |
| `redo` | REDO layout filesystem | `write`, `bs=4k`, `size=4G`, `numjobs=1`, `iodepth=1`, `fdatasync=1` |
| `fra-1m` | FRA layout filesystem | `readwrite`, `bs=1M`, `size=16G`, `numjobs=1`, `iodepth=8`, `rate=120M` |

The layout names describe FIO file placement only. No Oracle binaries, database files, database services, Swingbench workload, or AWR collection are in scope.

### Experiment Schedule and Decision Rules

The regular-settings baseline and every testable candidate run at 50 VPUs/GB for three measured repetitions. The generated `experiment_plan.json` records a random seed and three deterministic candidate-order blocks; each testable candidate appears exactly once in each block, while a different seeded permutation per block counterbalances time/order drift. Run three initial regular-settings baseline repetitions and one additional regular-settings checkpoint after every five candidate attempts. After all candidate measurements, execute the two non-measurement rollback canaries, prove full recovery, and then run three final regular-settings repetitions; no tuning mutation is permitted after that final baseline. A checkpoint that moves beyond the applicable stability/regression threshold pauses the experiment for drift investigation. The generated plan reconciles the discovered candidate count, repetitions, checkpoint count, two canary attempts, total FIO-run count, minimum 660-second-per-measured-run time, estimated transition/rollback time, and expected OCI cost before execution.

For every FIO job and metric, report the median, minimum, maximum, median absolute deviation, and coefficient of variation across the three repetitions. A configuration is stable when each primary measure’s CV is at most 5%; otherwise run up to two additional repetitions for that configuration. If the initial or final regular-settings baseline remains unstable, stop the 50-VPU experiment as inconclusive. An unstable candidate is ineligible for recommendation and is reported as inconclusive rather than silently discarded.

Primary measures are DATA IOPS, REDO p99 and p99.9 write-completion latency from `jobs[].write.clat_ns.percentile`, and FRA bandwidth. Report `sync.lat_ns` separately but do not substitute it for the REDO primary measure. A candidate is eligible only if it is stable; has no FIO, iSCSI, kernel, TCP, checksum, or restoration error or monitored error-class counter increment; improves at least one primary measure by more than `max(5%, 2 × baseline CV)`; does not regress any other primary measure or p99/p99.9 latency by more than that metric’s `max(5%, 2 × baseline CV)`; and increases median host CPU utilization by no more than 10% relative. The monitored error-class set is frozen in the plan and includes iSCSI/SCSI failures and timeouts, TCP retransmits/resets, NIC errors/drops, and new kernel block/network error records; ordinary byte, packet, and command counters are expected to rise and are not errors. Eligible candidates are Pareto-ranked at 50 VPUs/GB only. Ties prefer lower p99.9 REDO latency, then lower CPU use, then the configuration with fewer changed controls; if no candidate clears the noise and guardrails, the regular OCI/guest baseline is the recommendation.

Every results-index entry declares `attempt_type=measurement`, `checkpoint`, or `rollback_canary`. Only successful `measurement` rows contribute to repetition counts, CV, eligibility, Pareto ranking, and the recommendation. The two canaries use dedicated IDs `ROLLBACK_CANARY_TRAP` and `ROLLBACK_CANARY_LEASE`, record the safe source candidate separately, have expected failure outcomes, and never change that source candidate’s performance execution status.

### Safe Mutation, Activation, and Restoration

Before any candidate, archive exact baseline sysctl, TuneD, NIC, queue, IRQ, route, iSCSI node/session, block, LVM, filesystem, and mount state. Create a non-FIO 64 MiB sentinel on each mounted filesystem and record its SHA-256 digest. FIO files never overlap the sentinels; verify all three digests before and after every mutation and measured run.

For `ISCSI_QD128`, stop load, `sync`, unmount FRA/REDO/DATA, deactivate both VGs, update only `node.session.queue_depth` on the five target records through `iscsiadm`, log out all five sessions, log in exactly one portal per target, wait for devices, reactivate VGs, mount all filesystems, and verify topology and sentinels. Prove the live queue depth from detailed session/sysfs state and prove that congestion control on the new sockets remains at its captured baseline. Restoration repeats the safe reconnect sequence, restores only the captured queue-depth values through `iscsiadm`, and verifies both queue depth and baseline congestion control.

For a `TCP_CC_<name>` candidate, use the same stop/sync/unmount/VG-deactivate and reconnect safety boundary, but never update an iSCSI node record. Change only `net.ipv4.tcp_congestion_control`, log out and log in exactly one portal per target to create new sockets, restore storage, and prove the selected algorithm on the actual iSCSI sockets with `ss -ti` while proving queue depth remains at baseline. Restoration changes only congestion control, reconnects, and independently verifies baseline congestion control and queue depth. Queue depth and congestion control are never combined in one performance candidate.

Before a NIC, RPS/RFS/XPS, MTU, offload, coalescing, channel, ring, or TuneD mutation, install a root-owned baseline restore bundle and arm a host-local three-minute rollback unit. Cancel it only after local topology/integrity checks and an independent controller reachability check pass. Candidate completion always restores the full baseline, reconnects when required, verifies byte-for-byte configuration equality for applicable controls, validates sessions/topology/sentinels, and records `restored`. Failure, interruption, lost control connectivity, or an expired rollback lease ends the candidate as failed and blocks later candidates until baseline recovery is proven.

No candidate may reformat, repartition, detach, recreate, or mount over the established block-volume layout. No tuning state may leak into the next candidate.

### Regular Project Test Report

For every attempt, archive ASCII command logs plus valid raw FIO JSON when FIO runs, iostat JSON, OCI volume and attachment JSON, compute/image metadata, iSCSI node/session/socket state, block/LVM/filesystem/mount state, sysctl/NIC/TuneD/IRQ/queue inventory and delta, sentinel results, CPU utilization, and before/after kernel/TCP/network error counters. Each artifact is indexed by run ID, candidate ID, attempt type, `vpu=50`, repetition when applicable, UTC start/end timestamps, result, and restoration state in `results_index.json`.

Reuse `tools/render_fio_report_html.sh` and the existing OCI metrics collection/reporting path. Produce per-attempt FIO reports, a 50-VPU candidate comparison table, `fio_analysis.md`, aggregate `fio_report.html`, FIO-window OCI metrics Markdown and HTML reports, `sprint_30_summary.md`, and a machine-readable `recommendation.json`. The summary links every candidate to its raw evidence, coverage-ledger disposition and execution status, statistics, exclusions, guardrails, restoration proof, and recommendation decision. HTML must be standalone and the Markdown/HTML values must reconcile with the JSON index.

### Evidence and Recommendation

The final report applies the defined statistical and Pareto rules rather than choosing the largest raw result. It distinguishes an observed improvement from the four-OCPU instance network/IOPS ceiling, single-path limitation, volume tier, and workload concurrency. It explicitly labels all results as single-path characterization, not supported multipath/UHP entitlement, and retains the complete baseline restore bundle.

### Error Handling

- Stop before mutation if credentials, pinned image, exact shape/memory, online CPU topology, five-volume layout, effective 50-VPU setting, single-path state, routes, baseline capture, or sentinels cannot be proved.
- Treat OCI refusal of 50 VPUs/GB, any effective-value mismatch, or an automatically multipath-enabled attachment as a feasibility failure; do not fabricate a single-path run.
- Restore and stop when a session, device identity, LVM, mount, sentinel, FIO, kernel/TCP error, controller reachability, or effective-setting check fails.
- Mark an unavailable or unsafe control with an excluded planning disposition rather than forcing it. A discovered control without a disposition, an exclusion without evidence/reason, or a testable control still pending at closure fails completeness.
- A failed or byte-unequal restoration blocks further candidates and sprint closure.
- Live A3 requires valid OCI authentication and an approved disposable target. Missing prerequisites fail the live test; they are not converted into a skip/pass.

### Testing Strategy

#### Recommended Sprint Parameters

- **Test:** integration — validates the runner contract and executes FIO on the target environment.
- **Regression:** integration — the repository provides integration-only regression coverage.
- **Regression scope:** iscsi_tuning — runs only the single-path iSCSI tuning domain and its completed Sprint 30 evidence validation.

#### Regression Group

| Gate | Command | Included | Deliberately excluded |
| --- | --- | --- | --- |
| B3 integration regression | `tests/run.sh --integration --component iscsi_tuning` | `test_bv4db_iscsi_tuning.sh` through its no-argument `run_all` dispatcher | Historical Oracle Database, general block-volume, multipath, lifecycle/runbook, and prior-sprint report tests. |

The B3 group is intentionally narrow. IT-9 already validates the FIO and OCI-metrics report contracts produced by Sprint 30 itself; rerunning tests that inspect immutable Sprint 10–12 artifacts adds time without validating a changed Sprint 30 dependency. If construction later changes a shared renderer or metrics implementation, the directly affected test is added to this manifest with the dependency and reason recorded in the implementation document. B3 always receives `SPRINT30_EXECUTE_LIVE=0` and an existing `SPRINT30_TEST_OUTPUT_DIR`, so it validates evidence only and never repeats the live candidate matrix.

#### Unit Test Targets

| Component | Functions to Test | Key Inputs & Edge Cases | Isolation |
| --- | --- | --- | --- |
| None | The repository has no unit-test runner. | Not applicable. | Not applicable. |

#### Integration Test Scenarios

| Scenario | Infrastructure Dependencies | Expected Outcome | Est. Runtime |
| --- | --- | --- | --- |
| Static contract and deterministic plan | Repository checkout and local fixtures | Runner declares the five-volume layout, fixed 50-VPU Sprint 30 plan, FIO-only scope, exact FIO profile, exhaustive candidate ledger, reports, evidence, and safety guards. | < 1 minute. |
| Fail-closed and restoration fixtures | Repository checkout and command shims | Invalid topology and injected mutation failures stop before load or restore exact baseline state. | < 5 minutes. |
| Live topology and regular baseline | Approved four-OCPU OCI target and valid credentials | The target proves five effective-50, single-path volumes and completes at least three unchanged-settings FIO repetitions. | At least 33 minutes plus provisioning. |
| Live 50-VPU candidate matrix | Same approved target | Every testable candidate completes the scheduled repetitions with effective-setting, integrity, error-counter, and per-attempt restoration evidence. | `testable candidates × 3 × 11 minutes`, plus checkpoints, activation, and any stability reruns. |
| Rollback canary, reporting, and final state | Same approved target and completed matrix | The host-local lease restores a deliberately interrupted candidate; raw evidence, regular Markdown/HTML reports, recommendation, final baseline, and teardown all reconcile. | Approximately 20 minutes plus the final 33-minute baseline and teardown. |

#### Smoke Test Candidates

| Candidate | Why Critical | Expected Runtime |
| --- | --- | --- |
| None | Sprint configuration specifies integration only. | Not applicable. |

## Test Specification

Sprint Test Configuration:

- Test: integration
- Mode: managed

All ten tests live in the component/domain file `tests/integration/test_bv4db_iscsi_tuning.sh`. The file supports both selected-function dispatch for the Sprint 30 A3 manifest and no-argument `run_all` dispatch for component regression.

The A3 live sequence requires an explicit `SPRINT30_TEST_OUTPUT_DIR`, `SPRINT30_EXECUTE_LIVE=1`, valid OCI authentication, and approval to use the disposable target. IT-5 creates or resumes the one shared run; IT-6 through IT-10 reuse that run instead of reprovisioning. Missing live prerequisites or required artifacts fail rather than skip. B3 runs the `iscsi_tuning` manifest with the same immutable output directory and `SPRINT30_EXECUTE_LIVE=0`; it validates completed evidence and must not provision or mutate infrastructure again.

### Integration Tests

#### IT-1: Static runner and CLI contract

- **Preconditions:** Repository checkout.
- **Steps:** Verify shell syntax and executable entry points; plan-only default; fixed Sprint 30 value of 50 VPUs/GB; exact five-volume DATA/REDO/FRA layout; four-OCPU and single-path guards; exact FIO jobs and parameters; candidate, state, evidence, and report interfaces; use of `iscsiadm` rather than direct `/etc/iscsi/nodes` edits; and an explicit fresh-empty authorization before any destructive initialization.
- **Expected Outcome:** The declared interface is 50-VPU, FIO-only, evidence-producing, and fail-closed; neither Oracle execution nor an implicit destructive path is present.
- **Verification:** Run `test_IT1_static_runner_contract` and assert each contract field from executable plan output or stable machine-readable metadata, not source-text presence alone.
- **Target file:** `tests/integration/test_bv4db_iscsi_tuning.sh`.

#### IT-2: Deterministic 50-VPU experiment plan and coverage ledger

- **Preconditions:** Repository checkout and discovery fixtures containing supported, fixed, absent, and unsafe controls.
- **Steps:** Generate `experiment_plan.json` and `tunable_coverage.json` twice with the same explicit seed and normalized run metadata. Validate the VPU set, repeat blocks, candidate ordering, checkpoints, canaries, FIO count/runtime/cost calculations, stable candidate IDs, and every discovered control's planning disposition and initial execution status.
- **Expected Outcome:** Both canonical plan payloads are identical after excluding run ID, timestamp, and output path; their VPU set is exactly `[50]`; every `disposition=testable` candidate begins `execution_status=pending` and appears exactly once in each of three blocks; every excluded disposition has a reason and evidence path; the two dedicated rollback canaries are non-measurement attempts; counts reconcile; and no 30, 120, duplicate, or unknown candidate is present.
- **Verification:** Run `test_IT2_deterministic_50_vpu_plan` and validate both files with `jq` plus recomputed counts.
- **Target file:** `tests/integration/test_bv4db_iscsi_tuning.sh`.

#### IT-3: Fail-closed preflight matrix

- **Preconditions:** Local OCI/host command fixtures with one valid target and one fault per case.
- **Steps:** Exercise wrong OCPU or RAM, unpinned/different image, any volume not effective 50, multipath enabled or devices present, zero or multiple sessions per target, duplicate device identity, wrong stripes/filesystem/mount, inconsistent iSCSI route/interface, sentinel mismatch, and missing credentials.
- **Expected Outcome:** Every invalid case exits nonzero before mutation or FIO; apply and load command journals remain empty. The valid fixture reaches the planned state without mutation.
- **Verification:** Run `test_IT3_fail_closed_preflight_matrix` and assert exit code, terminal state, and empty mutation/FIO journals for every negative case.
- **Target file:** `tests/integration/test_bv4db_iscsi_tuning.sh`.

#### IT-4: Restore and resume state machine

- **Preconditions:** Local command shims and a byte-comparable baseline fixture.
- **Steps:** Inject apply/readback/FIO failures, `SIGTERM`, stale `applying` and `measuring` states, and baseline drift on resume. Exercise successful restore, failed restore, and clean resume.
- **Expected Outcome:** Every post-apply failure enters `restoring`; resume proceeds only from a byte-equal baseline; failed restoration blocks later candidates; atomic transitions are valid; logs contain no secret or ANSI escape sequence.
- **Verification:** Run `test_IT4_restore_resume_state_machine` and compare state/event journals and before/after baseline bundles.
- **Target file:** `tests/integration/test_bv4db_iscsi_tuning.sh`.

#### IT-5: Live 50-VPU topology and integrity preflight

- **Preconditions:** Approved disposable OCI target, valid credentials, explicit live flag, and shared output directory.
- **Steps:** Provision or resume the pinned `VM.Standard.E5.Flex` four-OCPU/32-GB host and five volumes; capture OCI, route, CPU, device, iSCSI, LVM, filesystem, mount, and sentinel evidence before mutation.
- **Expected Outcome:** All five volumes report effective 50 VPUs/GB; each requested single-path attachment is exactly bound, has no secondary endpoint, and never reports `is-multipath=true`; each target has exactly one guest session and unique persistent path with no multipath device; DATA and REDO are two-way 256-KiB stripes; FRA is direct; all mounts and sentinel digests are valid.
- **Verification:** Run `test_IT5_live_50_vpu_topology` and validate live evidence in `SPRINT30_TEST_OUTPUT_DIR` against OCI and guest observations.
- **Target file:** `tests/integration/test_bv4db_iscsi_tuning.sh`.

#### IT-6: Live regular-settings baseline at 50 VPUs/GB

- **Preconditions:** IT-5 passed and the regular guest baseline is captured.
- **Steps:** Execute three 600-second measured FIO repetitions after a 60-second ramp at fixed 50 VPUs/GB with unchanged guest settings; collect FIO, iostat, CPU, OCI metrics-window, topology, integrity, and error-counter evidence. Apply the defined stability extension when needed.
- **Expected Outcome:** Raw JSON is valid, exact DATA/REDO/FRA job options are present, OCI metric windows cover every attempt, configuration before/after is equal, and primary-measure CV is at most 5%; otherwise exactly up to two extra runs occur and an unresolved baseline is marked inconclusive with candidate execution blocked.
- **Verification:** Run `test_IT6_live_regular_50_vpu_baseline` and recompute repetition counts, options, metrics windows, statistics, and state transitions from raw artifacts.
- **Target file:** `tests/integration/test_bv4db_iscsi_tuning.sh`.

#### IT-7: Live complete candidate matrix at 50 VPUs/GB

- **Preconditions:** IT-6 produced a stable baseline and every discovered control has a planning disposition.
- **Steps:** Execute every `disposition=testable` ledger entry once in each of three seeded order blocks, including defined checkpoints and stability extensions; verify the effective value on the actual interface, session, or socket before FIO and restore after every attempt. Update execution status only from archived attempt evidence.
- **Expected Outcome:** Every testable candidate ends `tested`, `inconclusive`, or `failed`, with no `pending` entry; a tested candidate has exactly three successful measured repetitions unless the defined stability extension applies; every row remains `vpu=50`; excluded controls never execute; topology, sentinels, and monitored error-class counters remain valid; the complete baseline is byte-equal after each attempt; no candidate state leaks forward.
- **Verification:** Run `test_IT7_live_complete_candidate_matrix` and reconcile the coverage ledger, experiment plan, command journals, effective-setting evidence, and results index.
- **Target file:** `tests/integration/test_bv4db_iscsi_tuning.sh`.

#### IT-8: Host-local rollback lease canary

- **Preconditions:** Candidate measurements completed, live target restored to verified baseline, and one safe reversible source candidate selected by the plan.
- **Steps:** Run dedicated non-measurement attempt `ROLLBACK_CANARY_TRAP` and inject an ordinary FIO failure to exercise trap restoration. Separately run `ROLLBACK_CANARY_LEASE`, terminate controller/process control after verified application, allow the three-minute host-local lease to expire, and observe recovery independently. After recovery proof, execute the three final regular-settings repetitions and any defined stability extension; permit no later mutation.
- **Expected Outcome:** Both canaries have expected-failure/restored outcomes without altering the source candidate's execution status or performance sample count; sysctl/NIC/TuneD/iSCSI state, sessions, mounts, topology, and sentinels return to baseline; later execution stays blocked until recovery proof; no rollback unit remains armed; and the final baseline is stable before reporting.
- **Verification:** Run `test_IT8_live_rollback_lease_canary` and validate lease logs, independent post-expiry evidence, terminal states, and byte-equal baseline bundles.
- **Target file:** `tests/integration/test_bv4db_iscsi_tuning.sh`.

#### IT-9: Evidence, reports, and recommendation reconciliation

- **Preconditions:** Completed 50-VPU candidate matrix, rollback canaries, and stable final regular-settings baseline.
- **Steps:** Validate every results-index row and referenced artifact; parse raw JSON; check ASCII logs; validate coverage disposition/execution status, Markdown, and standalone HTML reports; independently recompute medians, MAD, CV, eligibility threshold, Pareto set, and tie-break decision from measurement rows only.
- **Expected Outcome:** Every row contains run/candidate, attempt type, `vpu=50`, applicable repetition, UTC timestamps, result, restoration state, and existing evidence paths. Raw bundles are complete; no testable control remains pending; canaries are excluded from performance statistics and source-candidate status; reports reconcile numerically with JSON; recommendation and exclusions trace to the defined rules and evidence; no ANSI or non-50 result is present.
- **Verification:** Run `test_IT9_reports_and_recommendation` and compare independent calculations with `fio_analysis.md`, `fio_report.html`, OCI metrics reports, `sprint_30_summary.md`, and `recommendation.json`.
- **Target file:** `tests/integration/test_bv4db_iscsi_tuning.sh`.

#### IT-10: Final state, FIO-only guard, and teardown

- **Preconditions:** Reporting completed or the run entered a terminal failure path.
- **Steps:** Validate the final regular-settings repetitions, baseline equality, sentinel digests, rollback-unit state, candidate state, evidence copy, teardown/keep-infra decision, and captured package/process/service command journals.
- **Expected Outcome:** Baseline is byte-equal, all sentinels match, no lease or candidate remains active, evidence is safe before teardown, terminal state records teardown success or approved keep-infra, and no Oracle Database package, binary, service, Swingbench workload, or AWR collection was installed or invoked.
- **Verification:** Run `test_IT10_final_state_fio_only_teardown` and inspect final state plus negative Oracle-execution evidence.
- **Target file:** `tests/integration/test_bv4db_iscsi_tuning.sh`.

### Traceability

| Backlog Item | Smoke | Unit Tests | Integration Tests |
| --- | --- | --- | --- |
| BV4DB-72 | Not applicable | Not applicable | IT-1 through IT-10 |

## Design Approval Status

Accepted by Product Owner on 2026-08-18. The approved execution tier was
subsequently changed from 45 to 50 VPUs/GB after OCI rejected 45; all Sprint
30 execution, plans, evidence, reports, and recommendation use 50 only.
