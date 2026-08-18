# Sprint 30 Agent Work Context No. 2

Date: 2026-08-18

## Stop point

The user stopped the work while Sprint 30 was still in Construction. Do not
start live OCI provisioning from this state. The latest RUP Constructor review
still classified the implementation as STOP-SHIP, and the edits made after
that review have not yet received a clean re-review or the complete local test
pass.

The parent repository is on `main`. The latest committed and pushed revision
is:

```text
08ece41 feat: (sprint-30) implement guarded single-path tuning runner
```

All work after that revision is uncommitted.

## Current worktree

Tracked modifications:

```text
M tests/integration/test_bv4db_iscsi_tuning.sh
M tools/oci_bv_single_path_guest.sh
M tools/oci_bv_single_path_tuning.sh
```

Untracked implementation:

```text
tools/analyze_bv_single_path.py
```

Other untracked paths that predate this handoff and must be preserved:

```text
progress/sprint_30/live_50vpu/
progress/sprint_30/test_run_A3_integration_20260818_120356.log
```

`progress/sprint_30/live_50vpu/` is historical/contaminated state. Never reuse
it as a live output directory, provisioning state, or teardown source. A future
live run must use a new empty, uniquely named output directory and newly owned
scaffold state.

`tools/__pycache__/` is also currently untracked and was produced by local
Python compilation. It is not evidence and should not be committed.

## Work completed after 08ece41

The controller and guest executor were hardened substantially, but the work is
not finished:

- The guest now validates the destructive fresh-layout authorization, rejects
  non-empty or mismatched devices fail-closed, creates and checks 64 MiB
  sentinels, and records device identities.
- Each measurement has an OCI and guest topology preflight before mutation.
- The rollback timer is renewed during the long FIO window; attempt cleanup
  kills FIO/iostat/lease workers, restores controls, and disarms the unit.
- Stability-extension control was added for initial baseline, candidates, and
  final baseline. Checkpoint drift is gated before canaries.
- A result-ledger bug was fixed so three through five successful repetitions
  can end as `tested` after stability extension.
- `analyze_bv_single_path.py` was added to compute primary FIO statistics,
  stability, initial eligibility guards, reports, and a recommendation.
- The guest was extended with a safe storage reconnect helper and candidate
  implementations for `ISCSI_QD128`, discovered `TCP_CC_*`, individual NIC
  offload inversions, ring maximum, channel maximum, adaptive coalescing, and
  the TuneD throughput profile.
- Control capture now includes iSCSI node queue depths, NIC offloads,
  ring/channel/coalescing state, and the active TuneD profile. Restoration and
  candidate readback checks were added.
- Online CPU masks are now derived from `/sys/devices/system/cpu/online`, and
  XPS assigns deterministic per-queue CPU masks instead of the all-CPU mask.
- Per-attempt guest context capture was added for iSCSI sessions/sockets,
  mounts, LVM, and block devices.
- The controller now begins to reconcile a live, discovery-driven catalogue
  from the pinned host and regenerates the live experiment plan before FIO.

No new live Sprint 30 resources were provisioned while making these changes.

## Last verification result

Immediately before this handoff:

- `bash -n` passed for both controller and guest scripts.
- `shellcheck` returned exit 1 because of warnings, so the verification gate is
  not clean. The warnings are:
  - SC2318 in `reconcile_live_catalogue` because `baseline` refers to
    `discovery` in the same `local` declaration.
  - False-positive-looking SC2100 warnings caused by strings such as
    `rx-checksumming` and `tx-checksumming` in compact `case` arms. Reformat or
    suppress only after confirming the code remains clear.
- Earlier, the integration component completed IT-1 through IT-4 successfully.
  IT-5 through IT-10 correctly failed because no
  `SPRINT30_TEST_OUTPUT_DIR` live evidence directory was supplied.
- The integration suite has not been rerun since the latest reconnect,
  discovery, NIC, and readback edits.

## Remaining STOP-SHIP work

The next agent must finish these items before any OCI mutation:

1. Fix all current ShellCheck findings and rerun `bash -n`, ShellCheck,
   `python3 -m py_compile`, and IT-1 through IT-4.
2. Finish and audit `reconcile_live_catalogue`. Confirm every discovered
   control is either testable or has an evidence-backed unsupported, unsafe,
   read-only, or not-applicable disposition. Confirm the regenerated plan and
   ledger have no duplicate IDs and reconcile candidate/checkpoint/runtime
   counts.
3. Change regular checkpoint rows to `attempt_type=checkpoint` throughout the
   plan, executor, index, analyzer, and tests. Only true measurement rows may
   contribute to candidate repetition counts and recommendation statistics.
4. Audit the new safe reconnect logic end to end. Restoration must preserve
   each captured queue depth, prove exact one-session/IQN/device binding,
   baseline congestion control on actual iSCSI sockets, mounts, LVM stripes,
   filesystems, sentinels, and boot-device exclusion.
5. Strengthen live topology evidence. `live_topology.json` currently contains
   some controller-asserted layout fields; derive and validate them from guest
   `lsblk`, `findmnt`, `pvs`, `vgs`, and `lvs` evidence instead.
6. Complete candidate apply/readback/restore validation for ring, channel,
   adaptive coalescing, offload, TuneD, iSCSI queue depth, and TCP congestion
   control. Ensure a failed or unsupported mutation cannot produce a passed
   row or `tested` ledger status.
7. Complete monitored error gates. The analyzer must cover NIC errors/drops,
   TCP retransmits/resets, iSCSI/SCSI failures/timeouts, and new kernel
   block/network errors. Host CPU must come from the accepted host-utilization
   evidence, and REDO sync latency must be reported separately.
8. Implement true Pareto dominance and the accepted tie order: lower REDO
   p99.9, then lower host CPU, then fewer changed controls.
9. Gate initial-versus-final baseline drift independently. Do not pool the two
   baseline groups in a way that can hide drift. Checkpoint movement must be
   evaluated in either direction against the accepted threshold.
10. Reconcile OCI metrics to each FIO attempt window. The current controller
    still generates a whole-matrix metrics report only.
11. Resolve incomplete CLI semantics. Live `--resume` is advertised but
    rejected, and selected `--candidate` execution can incorrectly leave other
    candidates failed. Either implement the accepted behavior safely or remove
    the unsupported interface and update tests/docs.
12. Request another read-only RUP Constructor review. Do not provision until
    it returns no STOP-SHIP findings.

## Safe continuation sequence

Read, in order:

1. repository `AGENTS.md`;
2. every file under `RUPStrikesBack/rules/generic/`;
3. `progress/sprint_30/sprint_30_setup.md`;
4. `progress/sprint_30/sprint_30_design.md`;
5. `progress/sprint_30/AGENTS_WORK_CONTEXT.md`;
6. this file.

Remember that `RUPStrikesBack/` is strictly read-only. Keep the parent project
on `main`; if `oci_scaffold/` ever needs changes, they belong only on its
`oci_bv4db_arch` branch. Preserve unrelated user changes and the historical
Sprint 30 artifacts listed above.

After the STOP-SHIP list is closed and the re-review is clean, create a fresh
50-VPU live A3 output directory, explicitly pin an available Oracle Linux 9
image OCID for `VM.Standard.E5.Flex`, and require both live authorization
environment flags. Never point execution at `live_50vpu/`. Poll the long run
without abandoning it, preserve plain-ASCII evidence, then run A3 and B3 from
the same immutable evidence directory. Verify teardown with read-only OCI
inventory before documenting and closing the sprint.

Only after A3 and B3 pass should the agent update Sprint 30 test/implementation
documents, `PROGRESS_BOARD.md`, `PLAN.md`, backlog links/status, commit the
remaining work with a RUP-compliant message, push, and report Sprint 30 done.
