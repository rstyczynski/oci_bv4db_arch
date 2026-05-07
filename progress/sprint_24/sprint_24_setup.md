# Sprint 24 - Setup

## Contract

- Rules reviewed: `AGENTS.md`, `RUPStrikesBack/rules/generic/*`, and RUP manager/agent instructions.
- Local patch status: `RUP_patch.md` is referenced by `AGENTS.md` but is not present in this checkout.
- Scope: only Sprint 24 and backlog items `BV4DB-56` and `BV4DB-57`.
- Constraints: `RUPStrikesBack/` remains read-only; `oci_scaffold/` is treated as a submodule on branch `oci_bv4db_arch`; no unrelated changes are reverted.
- Execution mode: YOLO. Sprint 24 is explicitly selected by the user even though the current working tree has `Status: Planned` in `PLAN.md`.
- Test parameters: `Test: integration`; `Regression: integration`.

## Analysis

### BV4DB-56

- Requirement: validate a simplified UHP iSCSI multipath path where the Oracle Cloud Agent Block Volume Management plugin owns connection and multipath setup.
- Existing pattern: Sprints 20-23 provision UHP multipath attachments but perform guest-side iSCSI login and/or custom dm-multipath policy work.
- Sprint 24 delta: enable the plugin before attachment, create the multipath-enabled OCI attachment, wait for agent-created iSCSI sessions and mapper device, mount the mapper path, and capture evidence.
- Feasibility: high. Oracle documents the plugin as required for UHP iSCSI multipath and states it performs iSCSI login for multipath-enabled attachments.

### BV4DB-57

- Requirement: define one operator evidence checklist and troubleshooting path for plugin-managed multipath.
- Existing pattern: prior sprint diagnostics capture `multipath -ll`, `multipathd show paths`, service status, and state JSON.
- Sprint 24 delta: consolidate those checks around plugin evidence: control-plane `is-multipath`, plugin config/logs, iSCSI sessions, mapper, mount, and common failure signatures.
- Feasibility: high. Oracle documents control-plane checking, guest reality checks, and common mismatch causes.

## YOLO Mode Decisions

### Assumption 1: Sprint 24 Is Active

**Issue:** `PLAN.md` currently says Sprint 24 is `Planned`, while the user explicitly requested Sprint 24 execution.
**Assumption Made:** Execute Sprint 24 without editing the `PLAN.md` status token.
**Rationale:** `PLAN.md` is Product Owner-owned and already has a user working-tree change.
**Risk:** Low; sprint artifacts and progress board still record execution.

### Assumption 2: Evidence Can Be Scripted Before Live Run

**Issue:** A clean live OCI run may depend on credentials, quota, and time.
**Assumption Made:** Implement the live runner and static integration validation; live evidence files are produced when the runner is executed in an OCI-ready environment.
**Rationale:** This matches prior sprint scripts and keeps repository validation deterministic.
**Risk:** Medium; final operational proof still requires a live run.
