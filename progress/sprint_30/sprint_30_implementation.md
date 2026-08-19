# Sprint 30 - Implementation Notes

## Implementation overview

**Sprint status:** implemented and tested
**Backlog item:** BV4DB-72 — tested
**Approved execution tier:** 50 VPUs/GB only  
**Scope:** five attached Block Volumes and their single iSCSI paths. The boot
volume is excluded from FIO, LVM/filesystem work, iSCSI mutation, and tuning.

## Phase purpose and current position

| RUP phase | Required artifact/purpose | Sprint 30 status |
| --- | --- | --- |
| Setup / inception | Define the problem, constraints, and feasibility prerequisites. | `sprint_30_setup.md` exists; OCI access verified. |
| Elaboration / design | Approved design and executable test specification. | `sprint_30_design.md` accepted; tier changed to 50 after the documented 45 failure. |
| Construction | Implement the approved command, fill the existing test skeletons, and prepare functional test sequences. | Complete; the final reusable-infrastructure matrix completed. |
| Quality gates | Run A3 first, then scoped B3, with timestamped logs and results in `sprint_30_tests.md`. | Complete; A3 passed 10/10 and B3 passed 10/10 (component 1/1). |
| Documentation | Reconcile design, implementation, evidence, test results, and backlog traceability. | Complete; canonical evidence and reports are linked from the test and documentation summaries. |

Product-owner clarification on 2026-08-19: every executed performance test
must create a written Markdown report, not only raw JSON and optional HTML.
The setup and design contracts now require `attempt_report.md` for baseline,
checkpoint, candidate screening, shortlist-validation, failed/interrupted, and rollback-
canary attempts. Construction and IT-9 must be updated before Sprint 30 can
pass; evidence produced before this clarification is incomplete under the new
contract.

The canonical Phase 4 result record is `sprint_30_tests.md`. It contains the
archived baseline values and direct links to every written and HTML FIO report.
Test measurements are not duplicated in implementation notes; this document
records what was built and the causes and fixes discovered during construction.

Product-owner correction on 2026-08-19: tuning results must become available
as each test finishes. Candidate execution therefore uses one screening
measurement, the existing archived baseline, and the reusable OCI topology;
each successful measurement is copied back and rendered to `fio_report.html`
before the next candidate begins. The iSCSI depth verifier now distinguishes
the exact configured request (128) from the effective value negotiated by the
target/SCSI layer. The effective value must be identical across all five
targets, greater than baseline, and no greater than 128. This permits the
observed configured-128/effective-113 state to run FIO while retaining exact
readback, reporting, and restoration gates.

## BV4DB-72 implementation

### OCI resource lifecycle correction

`oci_scaffold` is the mandatory resource lifecycle implementation. Per-run
scaffold state was a design error because it reprovisioned identical OCI
resources. The corrected controller separates immutable evidence directories
from one stable avq3 scaffold state, ensures/adopts that compute and five-volume
topology idempotently, and retains it after tests. Every candidate restores the
captured guest and storage configuration before the next candidate. Normal
completion or interruption never deletes OCI resources. Hard destruction is an
explicit exceptional recovery option used only when exact restoration fails.

### Implemented code

| Artifact | Purpose | Status | Tested |
| --- | --- | --- | --- |
| `tools/oci_bv_single_path_tuning.sh` | Deterministic candidate-only plan, archived baseline import, reusable scaffold lifecycle, pinned topology gates, restoration, and reports. | Complete | Live matrix and A3/B3 pass. |
| `tools/oci_bv_single_path_guest.sh` | Exact-device iSCSI login, boot-device exclusion, guarded empty-volume layout initialization, baseline capture, reversible candidates, FIO/iostat evidence, rollback canaries, and quiescence. | Complete | Live attempts, both rollback canaries, Bash syntax, and ShellCheck pass. |
| `tools/oci_bv_controller_lock.sh` | Atomic controller-lifetime exclusion with fail-closed live-owner handling and auditable stale-lock recovery. | Complete | Active-owner rejection and stale recovery pass in IT-4. |
| `tools/analyze_bv_single_path.py` | Primary/per-job statistics, stability/drift gates, error/CPU guards, Pareto ranking, tie-breaking, and Markdown/HTML recommendation reports. | Complete | Recommendation independently reconciled in IT-6/7/9. |
| `tools/index_oci_attempt_metrics.py` | Reconcile OCI Monitoring datapoints to each exact FIO attempt window. | Complete | Every indexed attempt window has the required datapoints. |
| `tools/verify_bv_single_path_results.py` | Independently recompute options, artifacts, timestamps, statistics, thresholds, Pareto choice, restoration, topology, and metric-window indexes. | Complete | Verified 20 indexed rows and 13 testable candidates. |
| `tests/integration/test_bv4db_iscsi_tuning.sh` | Ten approved integration-test functions in the `iscsi_tuning` domain, including one-shot live execution and immutable evidence validation. | Complete | A3 and scoped B3 pass all ten tests. |
| `tests/manifests/component_iscsi_tuning.manifest` | Narrow B3 regression group for the changed tuning domain only. | Complete | Manifest/dispatcher checked. |

### Real tuning command status

`tools/oci_bv_single_path_tuning.sh --execute` now implements the live path
against one reusable scaffold-owned infrastructure set. It does all of the
following against the five attached Block Volumes only:

1. logs in exactly one iSCSI path per volume with `iscsiadm`, never editing
   `/etc/iscsi/nodes` directly;
2. initializes the DATA/REDO/FRA layout only after explicit fresh-empty
   authorization, and never touches the boot device;
3. imports the accepted archived performance baseline, reuses the captured
   configuration and sentinels, applies one candidate at a time for one screening measurement, validates only
   shortlisted candidates with two additional measurements, restores the exact
   baseline after every attempt, and records evidence;
4. runs the two rollback canaries, report rendering and recommendation, then
   proves baseline restoration while retaining the OCI resources.

The reusable-infrastructure A3 live gate completed. The accepted evidence and
recommendation come from the measured matrix, not code inspection.

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

The next launch (`20260818_170951`) also stopped before guest preparation or
FIO. Immediately after the first iSCSI attachment reached `ATTACHED`, OCI
returned `is-multipath=null` and `multipath-devices=null`; the strict accepted
single-path gate rejected that non-boolean evidence. Failure cleanup deleted
the exact owned DATA1 volume and compute instance and proved an empty
run-tagged inventory. Oracle's current API documentation says the attachment
GET reports a boolean multipath value, so the controller first tried bounded
control-plane convergence while still requiring an explicit false/empty pair.
A second fresh attempt proved that the service persistently returns the
present-but-null pair on this explicitly requested single-path, four-OCPU
attachment. After the Product Owner directed continuation, the design was
corrected to use a conjunctive proof: requested false, a shape ineligible for
multipath, exact iSCSI binding and primary endpoint, no true/nonempty control-
plane value, and later exactly one guest session with no multipath device
before layout initialization or FIO. Wrong binding, a secondary endpoint,
true/nonempty/non-array values, query errors, or guest topology mismatch still
fail closed.

That attempt also exposed an independent plan-state serialization defect:
`resume:($resume|select(length>0))` emitted no object for a fresh run and left
`run_state.json` empty. The expression now records `resume:null`, and IT-1
requires a nonempty planned run state before any live provisioning.

The final managed-sprint safety review also required the guest's destructive
boundary to prove the same conjunction independently. Before any `pvcreate`
or `mkfs`, the guest now parses exact IQN tokens, requires exactly one session
for that IQN on the expected portal, rejects both leaf and global `mpath`
device types, and proves the persistent IQN binding. Production-function shims
cover wrong portals, IQN prefix collisions, same- and different-portal
duplicates, and leaf/global multipath; every fault is proven to stop before a
destructive-command marker. The fresh review returned GO.

The first run after that review (`20260818_174211`) passed the control-plane
proof for all five attachments and reached guest preparation, then stopped
before layout initialization because Oracle Linux appends a transport
annotation such as `(non-flash)` after the IQN in `iscsiadm -m session`
output. The parser had incorrectly required the IQN to be the final field.
All five volumes and compute were deleted and exact-tag inventory returned
zero. The parser now recognizes the expected IQN as an exact whitespace token
at any field position, counts every exact-IQN row before requiring cardinality
one, and independently checks the immediately preceding portal token. Test
fixtures include the real annotated format while retaining prefix-IQN and
mixed-portal duplicate rejection.

The next attempt (`20260818_175342`) passed the corrected parser, created the
authorized disposable layout, and then exited during baseline discovery before
any tuning or FIO. It produced no remote diagnostic because an unguarded
post-format discovery command failed under `errexit`; exact-tag cleanup again
proved zero resources. The most likely host-dependent operation was discovery
of an optional NIC `msi_irqs` directory, which is now represented as an empty
inventory when the driver exposes none. Guest preparation now has inherited
ERR tracing with an exact failing line, and the controller copies partial
guest discovery on prepare failure before scaffold cleanup. This converts any
remaining image-specific discovery failure into actionable evidence rather
than another opaque exit.

Attempt `20260818_180705` proved that guest preparation and initial topology
evidence were complete, then the first measurement preflight stopped before
tuning/FIO because the controller required the nonexistent OCI Block Volume
state `IN_USE`. The live API returned `AVAILABLE` at 50 VPUs/GB while the
separate attachment remained `ATTACHED`; Oracle's current Volume model lists
`AVAILABLE` but no `IN_USE` lifecycle enum. Cleanup again proved zero exact-tag
resources. The production gate now requires volume `AVAILABLE` at 50 plus the
independent exact attachment `ATTACHED` predicate, archives both raw responses
before evaluation, and has command-shim tests rejecting provisioning,
terminating, invented `IN_USE`, and wrong-tier values.

Attempt `20260818_182030` reached the first full 660-second FIO measurement.
Its restoration bundle was captured byte-for-byte equal to the immutable
baseline, but the attempt was rejected by a later undifferentiated restoration
gate before it could write `attempt.json`. The rollback lease remained armed,
the controller stopped the matrix, and exact-tag cleanup again proved zero
volumes and instances. The gate sequence showed that restore, capture, and
byte equality had passed; the first remaining check was `tuned-adm verify`.
Because the earlier implementation discarded that command's output, the exact
mismatch cannot be classified from the failed run. The command is now retried
for a bounded 30-second settling window, every response is archived as
plain-ASCII evidence, and persistent mismatch remains fail-closed. Every
restoration writes `restoration_checks.json` with individual exit codes and
`null` for checks not reached; the independent verifier requires TuneD
convergence when a profile is active, all other authoritative checks, and the
overall restoration result to be zero.

Attempt `20260818_185628` supplied the missing classification. TuneD verified
successfully on its first post-restore check, the bounded controls were
byte-identical, and live topology preflight passed. The only failing step was
`systemctl stop` for the transient rollback timer/service; its output had
previously been discarded. Cleanup again proved zero exact-tag volumes and
instances. Disarm now archives the stop response and both units' load/active
states. It tolerates a nonzero stop only when systemd explicitly identifies a
garbage-collected/not-loaded transient unit and both postconditions prove no
active timer or service. Generic stop failure and any active state remain
fail-closed, with focused production-function shims covering all three cases.

Attempt `20260818_194054` proved the corrected disarm path on its first regular
baseline repetition. The second repetition then recorded a real kernel iSCSI
`detected conn error (1020)` about 189 seconds after measurement began. This
coincided with the original transient timer deadline and exposed that
`systemctl restart` renewal did not postpone the one-shot deadline reliably;
the restore service was executing during a healthy measurement and was then
garbage-collected. Cleanup again proved zero resources. Renewal now atomically
moves a numeric deadline consumed by a five-second periodic systemd watchdog;
it never restarts the timer. A fresh deadline is inert, while expiry kills FIO
before waiting for the mutation lock and invokes emergency restoration. Local
shims prove renewal persistence, no timer restart, pre/post-deadline behavior,
emergency preemption order, and a deterministic expiry-versus-renewal
interleaving. Renewal/claim transitions share a dedicated lease-state lock;
once expiry is claimed, renewal fails, and emergency recovery revalidates the
claim after acquiring the mutation lock so stale checks cannot overwrite a
normal restore. Emergency recovery now archives and requires bounded TuneD
verification in addition to byte equality, topology, and sentinels, and all
watchdog terminal state is written by atomic rename.
The emergency commit writes and validates claim/unit-correlated evidence before
atomically disarming `rollback.json`; a fault-injection shim proves evidence
write failure leaves the prior armed/claimed state intact.

Attempt `20260818_203616` exercised that emergency path during the first
regular baseline. The periodic watchdog claimed expiry 363 seconds after it
was armed, terminated FIO, restored byte-identical controls, verified TuneD,
topology, and sentinels, and exact-tag cleanup again proved zero resources.
The measurement cannot be reused: FIO exited 128 and its interrupted output is
not valid JSON. The controller now renews every 30 seconds, uses bounded SSH
server-alive detection, and archives every guest-confirmed deadline plus a
monotonic renewal count in `lease_renewals.log`. Expiry evidence records the
observed deadline, observation epoch, and renewal count before terminal state
replacement, so any future expiry is attributable rather than inferred. A
failed/nonzero FIO attempt is rejected before report rendering, preventing an
invalid interrupted FIO document from obscuring the authoritative failure.

Attempt `20260818_211430` then proved three healthy regular-baseline runs and
continuous audited lease renewal, but no candidate ran. The background SSH
measurement inherited the process-substitution stream feeding the plan loop
and consumed every remaining plan row after the first row; the controller
therefore reached the final-baseline drift gate with no final baseline and
failed closed. Cleanup proved zero exact-tag resources. All SSH commands now
use OpenSSH `-n`, preventing them from reading controller stdin; the static
contract test requires that isolation before another live run.

Attempt `20260818_220616` showed the plan-stream fix in place, but the primary
measurement SSH connection declared the guest unreachable after only 15
seconds while independent renewal connections were still succeeding. The
guest completed FIO with exit zero, restored and verified the baseline, and
wrote complete attempt evidence, but the controller correctly refused to
adopt it after losing the primary command channel; cleanup again proved zero
resources. The SSH server-alive window is now 60 seconds (15 seconds times
four), still well inside the 180-second host-local deadline and independently
bounded by the 30-second renewal channel, while tolerating a short OCI network
pause that must not invalidate an otherwise supervised 660-second attempt.

Attempt `20260818_224723` completed five locally healthy initial-baseline
measurements. Every FIO command exited zero, controls restored byte-equal,
sentinels remained valid, the rollback lease disarmed, and monitored error
gates stayed clean. The old aggregate rule nevertheless stopped the run because
REDO p99.9 variability exceeded 5%; cleanup archived all six scaffold states as
deleted and `failure_cleanup_inventory.json` proved zero active tagged volumes
or instances. The Product Owner rejected repeated baselines as inappropriate
for this screening sprint and approved one smoke baseline, one run per
candidate, and two additional validation runs only for promising candidates.
The controller, analyzer, verifier, plan tests, and design contract now import
that archived baseline without another baseline FIO run.

The same run exposed a report-rendering defect: Oracle Linux 9 sysstat emitted
`rkB/s` and `wkB/s`, while `render_fio_report_html.sh` read only `rMB/s` and
`wMB/s`. Raw iostat collection was complete, but HTML throughput displayed as
zero. The shared renderer now accepts either schema and converts KiB/s to
MiB/s; all valid archived Sprint 30 attempt HTML reports were regenerated.

A later live retry also exposed a transient SSH reset during idempotent guest
package bootstrap. The bootstrap now retries for a bounded five-minute window;
the failed run's cleanup inventory proved that no OCI resources remained.

The first candidate screening then proved a driver dependency that discovery
could not infer from the top-level feature flags: disabling TX checksum also
disables TSO. Because the approved design forbids combined offload candidates,
`OFFLOAD_TX_CHECKSUM` is classified `unsafe` on this `virtio_net` target and is
not benchmarked. The same review found that the generated rotation had placed
NIC offload testing before iSCSI queue depth despite the approved catalogue
sequence. Planning now enforces iSCSI first and offloads last.

The next diagnostic run exposed a narrow controller/guest completion race: the
guest had persisted its restored/disarmed lease commit marker but its SSH
process had not yet exited, so the next heartbeat renewal correctly refused an
already-disarmed lease and the controller treated that refusal as failure. The
controller now accepts this terminal race only after an independent remote read
proves both `rollback_armed=false` and `restoration_state=restored`; any other
renewal failure remains fail-closed.

## Live environment status

OCI `avq3` profile access was validated against the active
`oci_bv4db_arch` compartment in `eu-zurich-1`. The completed matrix reused the
stable scaffold state in `progress/sprint_30/reusable_50vpu_avq3`. The final
restore proved the captured guest/storage baseline and retained the compute,
five volumes, and attachments for later tests. Earlier disposable feasibility
resources were independently deleted and are not part of the accepted result.

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
match its full adoption contract; the direct-created resource did not, so it
began to create a replacement rather than safely adopting it. The unintended 50-GB
replacement attachment was immediately detached and the replacement volume was
deleted. This confirms only that ad-hoc direct-created resources must not be
adopted through an incomplete scaffold state. Sprint 30 uses one complete,
stable scaffold-owned state and reuses it thereafter.

## Final quality-gate result

The canonical run is
`live_50vpu_20260819_avq3_reuse_qd_fix_0910`. A3 passed IT-1 through IT-10
(`10 passed, 0 failed`) and scoped B3 passed the same ten checks with the
component dispatcher reporting `1 passed, 0 failed`. The independent verifier
reconciled 20 result rows, 13 testable candidates, per-attempt reports, iostat,
OCI metric windows, restoration, and the `REGULAR_BASELINE` recommendation.
The final state proves byte-equal baseline restoration, valid sentinels, a
disarmed rollback lease, reused infrastructure, and retained resources.

The earlier A3 logs remain failure-history evidence and do not affect the final
gate. Full paths, baseline values, candidate interpretation, and rerunnable
test commands are recorded in `sprint_30_tests.md`.
