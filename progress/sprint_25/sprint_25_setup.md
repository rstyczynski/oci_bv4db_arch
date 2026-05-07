# Sprint 25 - Setup

## Contract

- Rules reviewed: `AGENTS.md`, `RUPStrikesBack/rules/generic/*`, and local RUP process instructions.
- Local patch status: `RUP_patch.md` is referenced by `AGENTS.md` but is not present in this checkout.
- Scope: Sprint 25 only, backlog item `BV4DB-58`.
- Constraints: `RUPStrikesBack/` remains read-only; `oci_scaffold/` is not modified; unrelated user changes are preserved.
- Execution mode: YOLO.
- Test parameters: `Test: integration`; `Regression: integration`.

## Analysis

### BV4DB-58

- Requirement: add a minimal Terraform setup that reflects the Sprint 24 OCI agent-managed multipath approach.
- Required operator shape: clean Oracle Linux compute, Oracle Cloud Agent Block Volume Management plugin enabled, UHP block volume, multipath-enabled iSCSI attachment, and documentation comparable with Sprint 24 manual/evidence.
- Existing source of truth: Sprint 24 runner and manual prove the OCI API request shape and guest evidence checklist.
- Feasibility: high for compute, volume, and plugin configuration through Terraform. The OCI provider currently exposes volume attachment multipath status as provider output rather than an argument, so the attachment itself needs a minimal Terraform-managed OCI API helper.

## YOLO Mode Decisions

### Decision 1: Minimal Terraform Module Instead Of Scaffold Refactor

**Ambiguity:** BV4DB-58 asks for a minimal Terraform setup, not a full replacement for project shell runners.
**Assumption Made:** Create a standalone example under `terraform/sprint25-agent-multipath/`.
**Rationale:** It keeps Sprint 24 behavior easy to compare and avoids changing `oci_scaffold`.
**Risk:** Low; the example is intentionally narrow.

### Decision 2: OCI API Helper For Multipath Attachment

**Ambiguity:** The Terraform provider does not accept `is_multipath` as a configurable attachment argument in the available schema.
**Assumption Made:** Use Terraform resources for instance and volume, and a `terraform_data` local-exec helper for the multipath attachment API call.
**Rationale:** This preserves Terraform as the orchestration entry point while still requesting `isMultipath: true`.
**Risk:** Medium; it depends on OCI CLI and `jq` on the operator workstation.
