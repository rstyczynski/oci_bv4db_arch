# /bug — Bug Management

Handle bugs discovered during sprints.

## Usage

```
/bug report <title> [--severity <low|medium|high|critical>] [--item <PBI-ID>]
/bug triage [<BUG-ID>]
/bug list [--sprint <N>] [--status <open|fixed|promoted>]
```

## Operations

### report

Register a bug found during sprint work.

**Steps:**
1. Identify current sprint from `PLAN.md` (Status: Progress)
2. Ask user for:
   - Symptom: exact error + where observed
   - Affected backlog item (or detect from context)
   - Severity: low, medium, high, critical
3. Create/update `progress/sprint_N/sprint_N_bugs.md`
4. Add entry using bug template

### triage

Evaluate bug for promotion to backlog item.

**Steps:**
1. Read bug entry from `progress/sprint_N/sprint_N_bugs.md`
2. Apply promotion criteria from `rules/generic/bug_policy.md`
3. If promotes:
   - Create new item in `BACKLOG.md`
   - Update `PROGRESS_BOARD.md`
   - Mark bug status as `promoted`
4. If fold-in: Confirm fix is part of current item scope

### list

Show bugs, optionally filtered.

**Steps:**
1. Read bug files from `progress/sprint_*/sprint_*_bugs.md`
2. Filter by sprint or status if provided
3. Display summary table

---

## Default Rule

Bugs discovered during a sprint are handled as part of the **current backlog item** (fold-in fix), unless they expand scope.

See `rules/generic/bug_policy.md` for full specification.

## Bug Entry Template

```markdown
## BUG-<N>: <Short title>

**Item:** <PBI-ID>
**Severity:** low | medium | high | critical
**Status:** open | fixed | promoted

- **Symptom**: exact error + where observed (command/gate/log path)
- **Root cause**: minimal causal explanation
- **Fix**: what changed (file/function-level)
- **Verification**: which Quality Gate/log proves resolution
```

## Promotion Criteria

Create a **new backlog item** when ANY is true:

| Criterion | Description |
|-----------|-------------|
| Scope expansion | Fix requires work beyond current item's requirement |
| Cross-cutting | Fix touches multiple backlog items/areas |
| Defer decision | Bug cannot be resolved in-sprint |

## Severity Guide

| Level | Response | Example |
|-------|----------|---------|
| Critical | Block sprint, fix immediately | Data loss, security hole |
| High | Fix before sprint close | Core feature broken |
| Medium | Fix if time permits | Edge case failure |
| Low | Can defer to next sprint | Cosmetic, minor UX |

## Quality Gate Bug Loop

When a Quality Gate fails:

1. Record bug in `sprint_N_bugs.md`
2. Fix the code (Construction loop)
3. Re-run the failing gate
4. Log new gate run in `sprint_N_tests.md`
