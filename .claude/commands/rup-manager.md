# RUP Cycle Manager - Complete Process Orchestration

Execute the complete Rational Unified Process cycle with test-first quality gates.

## Overview

This manager orchestrates all RUP phases by executing specialized agent instructions in sequence:

| Phase | Agents | Output |
|-------|--------|--------|
| Phase 1: Setup | Contractor + Analyst | `sprint_N_setup.md` |
| Phase 2: Design | Designer + Test Architect | `sprint_N_design.md` (includes test spec) |
| Phase 3: Construction | Constructor | `sprint_N_implementation.md` |
| Phase 4: Quality Gates | Test Executor | logs + `sprint_N_tests.md` |
| Phase 5: Wrap-up | Documentor | README + traceability |

## Instructions

Execute all five phases in sequence. Each phase reads and executes its specialized agent's instructions. The manager handles transitions, git commits, and maintains flow continuity.

---

## Step 0: Detect Mode and Test Parameters (ONCE)

**Before starting any phases, determine execution parameters:**

1. **Read PLAN.md**
2. **Identify the active Sprint** (Sprint with `Status: Progress`)
3. **Extract parameters:**

| Parameter | Values | Default |
|-----------|--------|---------|
| `Mode:` | `managed`, `YOLO` | `managed` |
| `Test:` | `smoke`, `unit`, `integration`, `none` | `unit, integration` |
| `Regression:` | `smoke`, `unit`, `integration`, `none` | `unit, integration` |
| `Regression scope:` | component name | (full suite) |

See `rules/generic/sprint_definition.md` for parameter details.

4. **Display Combined Banner:**

```text
═══════════════════════════════════════════════════════════════
SPRINT [N] | MODE: [YOLO|managed] | Test: [values] | Regression: [values]
═══════════════════════════════════════════════════════════════
```

If **YOLO Mode**:
```
YOLO: All outputs self-approved, no waits, 10-min limit.
- Agents make reasonable assumptions
- All decisions logged in implementation docs
- Critical failures still stop execution
```

If **Managed Mode**:
```
MANAGED: Human-supervised at each phase.
- Explicit approvals required
- Agents ask for clarification
- Recommended for complex/high-risk work
```

**All subsequent phases use this banner. Do NOT re-read PLAN.md for mode or sprint number.**

---

## YOLO Mode Speed Directive

**TIME LIMIT:** Complete all 5 phases in MAX 10 minutes.

**Speed Rules:**
- Write MINIMAL documentation (bullets, not paragraphs)
- Reference previous Sprints instead of re-explaining
- Skip verbose examples - write code instead
- Design: Endpoint list + data structures ONLY
- Tests: Test table + pass/fail results ONLY
- Max 3 YOLO decisions per phase (3 lines each)
- NO redundant text, NO over-explanation

---

## Phase 1: Execute Setup (Contracting + Inception)

Read `.claude/commands/agents/agent-contractor.md` and `.claude/commands/agents/agent-analyst.md` — skip Step 0 (mode detection) in both; mode is already set in the Step 0 banner.

Produce a **single file** `progress/sprint_N/sprint_N_setup.md` with two sections:

```markdown
## Contract
[contractor output: rules understood, responsibilities, constraints, open questions]

## Analysis
[analyst output: backlog items analyzed, feasibility, compatibility, open questions]
```

Update `PROGRESS_BOARD.md`: Sprint → `under_analysis`; Backlog Items → `analysed`

**Decision Point:** If any critical ambiguity exists in either section, stop and request clarification.

**Commit:** `docs(sprint-N): setup phase — contract and analysis` · Push.

---

## Phase 2: Execute Design + Test Specification

Read `.claude/commands/agents/agent-designer.md` — skip Step 0 and Step 8 ("Await Approval").

- **YOLO mode:** Self-approve immediately after writing; no wait.
- **Managed mode:** Wait for explicit Product Owner approval before continuing.

The design document `progress/sprint_N/sprint_N_design.md` **MUST** include a `### Testing Strategy` section. See `rules/generic/testing_strategy_template.md` for the required format.

**Immediately after writing the design** (no separate commit), execute Test Architect procedure from `rules/generic/test_procedures.md` Part 1:

1. Read the `### Testing Strategy` section and the `Test:` param from the Step 0 banner
2. Append a `## Test Specification` section to `sprint_N_design.md` (SM-N / UT-N / IT-N + traceability table)
3. Append test skeletons to existing files in `tests/smoke/`, `tests/unit/`, `tests/integration/` (one file per component/domain, not per sprint)
4. Register new tests in appropriate `tests/manifests/component_*.manifest`
5. Write `progress/sprint_N/new_tests.manifest` (format: `suite:script[:function]`)
6. Verify skeletons run and produce expected failures: `tests/run.sh --unit`

Update `PROGRESS_BOARD.md`: Backlog Items → `designed` → `test_specified`

**Decision Point:** If test scope is unclear after reading the Testing Strategy, stop and request clarification before writing skeletons.

**Commit:** `docs(sprint-N): design, test spec, and test skeletons` · Push.

---

## Phase 3: Execute Construction

Read `.claude/commands/agents/agent-constructor.md` — skip Step 0.

**Override:** Do NOT create new test cases. Tests were already specified in Phase 2. The Constructor:

1. Implements code to satisfy the design
2. Fills in any `# TODO: implement` stubs in test skeletons
3. Does NOT invent new test cases

Produce `progress/sprint_N/sprint_N_implementation.md`.

Update `PROGRESS_BOARD.md`: Sprint → `under_construction`; Backlog Items → `under_construction`

**Commit:** `feat(sprint-N): implement [brief description]` · Push.

**Do NOT proceed to Phase 5. Proceed to Phase 4.**

---

## Phase 4: Execute Quality Gates

Execute Test Executor procedure from `rules/generic/test_procedures.md` Part 2. Use `Test:` and `Regression:` from the Step 0 banner.

### Mandatory Log Artifacts

Every gate execution **MUST** produce a timestamped log file:

```bash
TS="$(date -u '+%Y%m%d_%H%M%S')"
LOG="progress/sprint_N/test_run_<gate>_${TS}.log"
tests/run.sh --<level> [flags] 2>&1 | tee "$LOG"
```

Gate names: `A1_smoke`, `A2_unit`, `A3_integration`, `B1_smoke`, `B2_unit`, `B3_integration`

### Phase A: New-Code Gates (per `Test:` parameter)

Run only new tests from `new_tests.manifest`. Each must pass before the next:

| Gate | Command | Condition |
|------|---------|-----------|
| A1 Smoke | `tests/run.sh --smoke --new-only progress/sprint_N/new_tests.manifest` | if `Test:` includes `smoke` |
| A2 Unit | `tests/run.sh --unit --new-only progress/sprint_N/new_tests.manifest` | if `Test:` includes `unit` |
| A3 Integration | `tests/run.sh --integration --new-only progress/sprint_N/new_tests.manifest` | if `Test:` includes `integration` |

A1 fail = skip A2/A3 (build is too broken).

### Phase B: Regression Gates (per `Regression:` parameter)

Run after Phase A passes. Full suite unless `Regression scope:` is set:

| Gate | Command | Condition |
|------|---------|-----------|
| B1 Smoke | `tests/run.sh --smoke [--component <scope>]` | if `Regression:` includes `smoke` |
| B2 Unit | `tests/run.sh --unit [--component <scope>]` | if `Regression:` includes `unit` |
| B3 Integration | `tests/run.sh --integration [--component <scope>]` | if `Regression:` includes `integration` |

### Retry Policy

| Mode | Retries 1-4 | Retry 5 | Retries 6-10 | After 10 |
|------|-------------|---------|--------------|----------|
| Managed | Auto fix-and-rerun | Human escalation | Continue if approved | Sprint `failed` |
| YOLO | Auto fix-and-rerun | Auto | Auto | Sprint `failed` |

See `rules/generic/test_failure_classification.md` for flaky vs broken handling.

### YOLO Mode Thresholds

| Test Level | Required Pass Rate |
|------------|-------------------|
| Smoke | 100% (no exceptions) |
| Unit | 100% (no exceptions) |
| Integration | ≥80% with failures documented |

### On Failure

1. Hand failure report to Constructor (Phase 3)
2. Constructor fixes the code
3. Test Executor re-runs the failing gate
4. Repeat until pass or retries exhausted

Produce `progress/sprint_N/sprint_N_tests.md` with `## Artifacts` listing all log paths.

Update `PROGRESS_BOARD.md`: Items → `smoke_passed` / `unit_tested` / `integration_tested` / `tested` (or `failed`); Sprint → `implemented` / `implemented_partially` / `failed`.

**Commit:** `test(sprint-N): quality gates — [pass/fail summary]` · Push.

**Phase 5 only after all gates pass (or YOLO threshold met). If retries exhausted → mark `failed`, still run Phase 5 for documentation.**

---

## Bug Handling

Bugs discovered during phases follow `rules/generic/bug_policy.md`:

- **Fold-in:** Fix as part of current backlog item (default)
- **Promote:** Create new backlog item if scope expands

Register bugs in `progress/sprint_N/sprint_N_bugs.md`.

---

## Phase 5: Execute Wrap-up

Read `.claude/commands/agents/agent-documentor.md` and execute with these focuses:

1. **Update `README.md`** — Add `### Sprint N — [title]` to Recent Updates section
2. **Create backlog traceability symlinks** in `progress/backlog/[ITEM-ID]/`
3. **Inline compliance check** (verify before committing):
   - All sprint artifacts exist: `setup.md`, `design.md`, `implementation.md`, `tests.md`, log files
   - No `exit` commands in copy-paste blocks
   - All log file paths listed in `tests.md ## Artifacts`
4. **Verify PROGRESS_BOARD.md** final state is correct

**Commit:** `docs(sprint-N): update README and backlog traceability` · Push.

---

## Step 6: Final Summary (MANDATORY)

**CRITICAL**: After all phases complete, you MUST provide this summary.

```markdown
# RUP Cycle — Sprint [N] Completion Report

Sprint: N | Mode: [YOLO|managed] | Status: [implemented|implemented_partially|failed]

## Phases Executed

| Phase | Status | Output |
|-------|--------|--------|
| Phase 1 Setup | done | sprint_N_setup.md |
| Phase 2 Design | done | sprint_N_design.md (includes test spec) |
| Phase 3 Construction | done | sprint_N_implementation.md |
| Phase 4 Quality Gates | [pass/fail] | [N] log files + sprint_N_tests.md |
| Phase 5 Wrap-up | done | README + backlog traceability |

## Backlog Items

| Item | Status | Tests |
|------|--------|-------|
| PBI-N | tested/failed | N pass / N fail |

## Quality Gates

| Gate | Result | Retries |
|------|--------|---------|
| A1 Smoke | [pass/skip/fail] | N |
| A2 Unit | [pass/skip/fail] | N |
| A3 Integration | [pass/skip/fail] | N |
| B1 Smoke | [pass/skip/fail] | N |
| B2 Unit | [pass/skip/fail] | N |
| B3 Integration | [pass/skip/fail] | N |

## Test Parameters

- Test: [value]
- Regression: [value]
- Regression scope: [component or "full suite"]
- Flaky tests deferred: [list or "None"]

## Commits

- [hash] docs(sprint-N): setup phase — contract and analysis
- [hash] docs(sprint-N): design, test spec, and test skeletons
- [hash] feat(sprint-N): implement [description]
- [hash] test(sprint-N): quality gates — [summary]
- [hash] docs(sprint-N): update README and backlog traceability

## Files Modified

[list all modified/created files]

## Deferred Items

[list or "None"]
```

---

## Orchestration Notes

### Error Handling

If any phase encounters issues:
- Stop execution at that phase
- Report the issue clearly
- Preserve partial progress via git commits
- Wait for Product Owner clarification
- Can resume by re-invoking this manager

### State Management

- PROGRESS_BOARD.md tracks Sprint and Backlog Item states
- Each phase updates its respective sections
- Git commits serve as synchronization checkpoints

### Phase Independence

Individual agents can still be invoked separately:
- Useful for resuming after manual fixes
- Allows targeted phase re-execution

---

## Execution Checklist

**IMPORTANT**: The RUP Manager MUST complete ALL 6 steps:

- [ ] **Step 0** — Mode + test params detected; banner displayed
- [ ] **Phase 1** — Setup (contract + analysis) → `sprint_N_setup.md` → commit, push
- [ ] **Phase 2** — Design + test spec + skeletons → `sprint_N_design.md` + `new_tests.manifest` → commit, push
- [ ] **Phase 3** — Construction (no new tests) → `sprint_N_implementation.md` → commit, push
- [ ] **Phase 4** — Quality gates (Phase A + Phase B) → log files + `sprint_N_tests.md` → commit, push
- [ ] **Phase 5** — Wrap-up (README + backlog traceability) → commit, push
- [ ] **Step 6** — Final Summary (MANDATORY — never skip)

---

## Related Rules

| Rule File | Purpose |
|-----------|---------|
| `rules/generic/sprint_definition.md` | Sprint format, Test/Regression params |
| `rules/generic/backlog_item_definition.md` | Backlog item format |
| `rules/generic/testing_strategy_template.md` | Designer's testing strategy template |
| `rules/generic/test_procedures.md` | Test Architect + Executor procedures |
| `rules/generic/test_failure_classification.md` | Flaky vs broken handling |
| `rules/generic/bug_policy.md` | Bug fold-in vs promote |

---

## Usage

To execute a complete RUP cycle:

1. Ensure PLAN.md has a Sprint with `Status: Progress` and required fields (`Mode:`, `Test:`, `Regression:`)
2. Invoke this manager: `/rup-manager`
3. Manager automatically executes all 6 steps
4. Verify all checklist items are completed

**Note**: For manual phase control, invoke individual agent commands directly (see `agents/README.md`).
