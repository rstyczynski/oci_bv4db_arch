# Sprint 26 - Setup

## Contract

Sprint 26 executes BV4DB-60 in YOLO mode.

Rules reviewed:

- `AGENTS.md`
- `RUPStrikesBack/rules/generic/GENERAL_RULES.md`
- `RUPStrikesBack/rules/generic/sprint_definition.md`
- `RUPStrikesBack/rules/generic/test_procedures.md`
- `RUPStrikesBack/rules/generic/bug_policy.md`

## Analysis

BV4DB-60 is a clean follow-up to the failed Sprint 25 native probe. The requirement is to test Oracle's documented UHP attachment behavior from a fresh Terraform state, avoiding raw API helpers, guest-side setup commands, and provider toggles that bypass the Block Volume Management plugin discovery path.

The sprint reuses Sprint 1 shared OCI context for compartment, subnet, and region. The live test uses a temporary Terraform working directory and temporary SSH key so the probe is isolated from Sprint 25 state.

## YOLO Decisions

- **Ambiguity:** Whether a negative vanilla result should fail the sprint.
- **Assumption:** A documented negative result satisfies BV4DB-60 because the backlog explicitly allows either positive evidence or a recorded negative result.
- **Risk:** Medium; a negative result is still useful only if the evidence captures exact OCI and guest state.
