# Sprint 24 - Setup

Status: Progress
Mode: YOLO
Test: integration
Regression: integration

## Scope

Sprint 24 executes:

- BV4DB-56. Validate simplified multipath setup fully managed by OCI Block Volume Management plugin
- BV4DB-57. Define and validate evidence checklist for OCI agent-managed multipath

## Contract (Rules Acknowledgement)

- Follow repository rules in `AGENTS.md`.
- Apply upstream RUP rules from `RUPStrikesBack/rules/generic/`.
- Apply local test-evidence rules from `RUP_patch.md` (no “tests passed” claims without committed log artifacts).
- Do not modify `RUPStrikesBack/` (read-only submodule).
- Do not modify `oci_scaffold/` unless explicitly required by the sprint scope.

## Analysis

Current state:

- The project’s multipath sprints (20–23) establish guest-side multipath diagnostics, A/B benchmarking, and fstab persistence workflows.
- Sprint manuals note that OCI Console “Block Volume Management” plugin signals can be misleading for the project’s custom layout (warnings are not treated as ground truth).

Need addressed by this sprint:

- Establish a *simplified* multipath attachment/maintenance path where the Oracle Cloud Agent **Block Volume Management plugin** is treated as the primary manager of multipath configuration (per Oracle docs), and define what constitutes “plugin-managed multipath is healthy” based on observable evidence.

Constraints:

- Live OCI execution may be gated by credentials/capacity/cost. If live validation cannot be run, the sprint must record gates as **NOT RUN** with reasons and a clear operator runbook for collecting the required evidence.

