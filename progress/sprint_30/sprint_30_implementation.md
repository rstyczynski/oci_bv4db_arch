# Sprint 30 - Implementation Notes

## Implementation overview

**Sprint status:** under_construction  
**Backlog item:** BV4DB-72 — under_construction  
**Approved execution tier:** 50 VPUs/GB only  
**Scope:** five attached Block Volumes and their single iSCSI paths. The boot
volume is excluded from FIO, LVM/filesystem work, iSCSI mutation, and tuning.

## Phase purpose and current position

| RUP phase | Required artifact/purpose | Sprint 30 status |
| --- | --- | --- |
| Setup / inception | Define the problem, constraints, and feasibility prerequisites. | `sprint_30_setup.md` exists; OCI access verified. |
| Elaboration / design | Approved design and executable test specification. | `sprint_30_design.md` accepted; tier changed to 50 after the documented 45 failure. |
| Construction | Implement the approved command, fill the existing test skeletons, and prepare functional test sequences. | Complete; final RUP safety re-review returned GO for a fresh live A3. |
| Quality gates | Run A3 first, then scoped B3, with timestamped logs. | Initial A3 failed before the executor existed; a fresh A3 is pending. |
| Documentation | Reconcile design, implementation, evidence, test results, and backlog traceability. | Not started; cannot start before construction/gates finish. |

## BV4DB-72 implementation

### OCI resource lifecycle correction

`oci_scaffold` is the mandatory resource lifecycle implementation for this
project. The initial disposable instance and Block Volumes were created through
direct OCI CLI while construction was incomplete; that was a process error.
No guest tuning or FIO ran through that path. The implemented controller now
uses a new output directory and a run-unique scaffold name for the compute and
each of the five volumes. It rejects adopted resources, masked helper failures,
non-Oracle-Linux-9 images, non-50-VPU volumes, or multipath attachments. Normal
cleanup quiesces the guest, tears down the five volume state files in reverse
order, and terminates compute only after every volume teardown succeeds.

### Implemented code

| Artifact | Purpose | Status | Tested |
| --- | --- | --- | --- |
| `tools/oci_bv_single_path_tuning.sh` | Deterministic plan, fresh scaffold lifecycle, pinned-image/topology gates, remote orchestration, attempt index, reports, and ordered teardown. | Implemented; live validation pending | IT-1--IT-4 pass locally. |
| `tools/oci_bv_single_path_guest.sh` | Exact-device iSCSI login, boot-device exclusion, guarded empty-volume layout initialization, baseline capture, reversible candidates, FIO/iostat evidence, rollback canaries, and quiescence. | Implemented; live validation pending | Bash syntax and ShellCheck pass. |
| `tools/oci_bv_controller_lock.sh` | Atomic controller-lifetime exclusion with fail-closed live-owner handling and auditable stale-lock recovery. | Implemented; live validation pending | Active-owner rejection and stale recovery pass in IT-4. |
| `tools/analyze_bv_single_path.py` | Primary/per-job statistics, stability/drift gates, error/CPU guards, Pareto ranking, tie-breaking, and Markdown/HTML recommendation reports. | Implemented; live validation pending | Python compilation passes; independent live reconciliation is specified in IT-6/7/9. |
| `tools/index_oci_attempt_metrics.py` | Reconcile OCI Monitoring datapoints to each exact FIO attempt window. | Implemented; live validation pending | Python compilation passes. |
| `tools/verify_bv_single_path_results.py` | Independently recompute options, artifacts, timestamps, statistics, thresholds, Pareto choice, restoration, topology, and metric-window indexes. | Implemented; live validation pending | Python compilation passes; invoked by IT-6/7/9. |
| `tests/integration/test_bv4db_iscsi_tuning.sh` | Ten approved integration-test functions in the `iscsi_tuning` domain, including one-shot live execution and immutable evidence validation. | Implemented; live validation pending | IT-1--IT-4 pass; IT-5--IT-10 require the completed live directory. |
| `tests/manifests/component_iscsi_tuning.manifest` | Narrow B3 regression group for the changed tuning domain only. | Complete | Manifest/dispatcher checked. |

### Real tuning command status

`tools/oci_bv_single_path_tuning.sh --execute` now implements the live path
against fresh scaffold-owned resources. It does all of the following against
the five attached Block Volumes only:

1. logs in exactly one iSCSI path per volume with `iscsiadm`, never editing
   `/etc/iscsi/nodes` directly;
2. initializes the DATA/REDO/FRA layout only after explicit fresh-empty
   authorization, and never touches the boot device;
3. captures baseline state and sentinels, applies one candidate at a time,
   proves the effective setting, executes three FIO repetitions, restores the
   exact baseline, and records evidence;
4. runs the two rollback canaries, final regular baseline, report rendering,
   recommendation, evidence copy, and teardown.

The command remains unverified until the fresh A3 live gate completes. No
performance claim or recommendation is accepted from code inspection alone.

Before live execution, the final read-only RUP safety review confirmed that
all stop-ship findings were closed. The reviewed controls include exact OCI
attachment-to-volume/instance binding, `is-multipath=false`, x86-64 guest
identity, per-socket congestion-control proof, conservative TuneD exclusion,
controller- and attempt-lifetime exclusion, strict rollback timer/service
disarm, canary observation-pending state, byte-equal resume proof, and
production-function command-shim coverage. The local pre-live gate passed
Bash syntax, ShellCheck, Python compilation, `git diff --check`, and IT-1
through IT-4.

The first post-review provisioning launch (`20260818_165450`) was deliberately
interrupted before guest preparation or FIO when scaffold progress output was
found to contain ANSI cursor controls in the persistent A3 log. The one owned
DATA1 volume and compute instance were deleted and independently observed as
`TERMINATED`; the failed log was converted to plain ASCII and the directory is
never reused. That interruption exposed an asynchronous-create cleanup race,
so failure recovery now polls exact run-tag names through a bounded OCI
creation/visibility horizon, reconstructs incomplete states, tears down only
unique exact-name resources through the scaffold, and requires a full stable
zero-resource interval after the horizon. IT-4 covers delayed visibility,
attached-volume state recovery, exact-name decoys, duplicate matches, query
failure, and zero-state stabilization. A later A3 launch uses an inline ANSI
filter before `tee` so persistent logs remain plain ASCII from creation.

## Live environment status

OCI `DEFAULT` profile access was validated against the active
`oci_bv4db_arch` compartment in `eu-zurich-1`. A temporary direct-CLI
four-OCPU target and five 50-VPU volumes were used only to validate OCI tier
acceptance; they did not follow the required scaffold lifecycle. All of those
resources and their attachments have now been detached/deleted/terminated.
No live Sprint 30 benchmark resource is currently active, and no guest login,
filesystem, FIO, tuning command, or boot-volume change has occurred.

## Recorded failure: 45 VPUs/GB

On 2026-08-18 OCI accepted the disposable four-OCPU target but rejected a
200-GB Block Volume request at 45 VPUs/GB before creating a volume:

| Field | Recorded value |
| --- | --- |
| OCI operation | `create_volume` |
| HTTP status / code | `400 InvalidParameter` |
| OCI message | `vpusPerGB is invalid or incorrectly formatted.` |
| Evidence | `oci_45_vpu_feasibility_20260818_120501.log` |
| Cleanup | First disposable instance terminated with boot-volume deletion; no guest mutation or FIO occurred. |

The Product Owner changed the fixed Sprint 30 tier to 50 VPUs/GB. The 45-VPU
failure is feasibility evidence only and must never be included in a benchmark
comparison or recommendation.

### Recorded construction failure: incomplete scaffold adopter

The first attempt to adopt the temporary direct-created volumes with
`ensure-blockvolume.sh` was stopped. That helper expects a reusable volume to
be `AVAILABLE`; an attached direct-created volume is `IN_USE`, so it began to
create a replacement rather than safely adopting it. The unintended 50-GB
replacement attachment was immediately detached and the replacement volume was
deleted. This confirms that Sprint 30 must begin with fresh, scaffold-owned
resources rather than custom adoption of direct-created resources.

## Quality-gate result to date

`test_run_A3_integration_20260818_120356.log` records the initial A3 attempt:
IT-1 through IT-4 passed. IT-5 through IT-10 failed as designed because no
completed live evidence directory exists. This is not a passing gate and B3
must not run until the executor and live evidence are complete.
