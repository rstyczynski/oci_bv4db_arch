# /sprint — Sprint Management

Manage sprints in `PLAN.md`.

## Usage

```
/sprint create [<N>] [--title <title>] [--items <ID1,ID2,...>]
/sprint status [<N>]
/sprint close [<N>]
/sprint start [<N>]
```

## Operations

### create

Create a new sprint entry in `PLAN.md`.

**Steps:**
1. Read `PLAN.md` to find next sprint number (or use provided N)
2. Read `BACKLOG.md` to validate item IDs
3. Ask user for:
   - Title (short description of sprint goal)
   - Mode: `managed` or `YOLO`
   - Test levels: `smoke`, `unit`, `integration`, or `none`
   - Regression levels: `smoke`, `unit`, `integration`, or `none`
   - Backlog items to include (if not provided via --items)
4. Validate all required fields present
5. Append sprint to `PLAN.md`
6. Update `PROGRESS_BOARD.md` — add items with status "Planned"

### status

Show sprint status.

**Steps:**
1. Read `PLAN.md`
2. If N provided, show that sprint; otherwise show active sprint (Status: Progress)
3. Display: status, mode, test/regression requirements, items, progress from PROGRESS_BOARD.md

### start

Start a sprint (transition from Planned to Progress).

**Steps:**
1. Verify sprint exists and has Status: Planned
2. Update sprint status to "Progress" in `PLAN.md`
3. Update `PROGRESS_BOARD.md` — items to "under_analysis"

### close

Complete a sprint.

**Steps:**
1. Verify all quality gates passed (check `progress/sprint_N/sprint_N_tests.md`)
2. Update sprint status to "Done" in `PLAN.md`
3. Update `PROGRESS_BOARD.md` — move items to "Done"
4. Optionally prompt for retrospective notes

---

## Format

See `rules/generic/sprint_definition.md` for full specification.

```markdown
## Sprint <N> - <Title>

Status: Planned | Progress | Done
Mode: managed | YOLO
Test: <smoke | unit | integration | none>
Regression: <smoke | unit | integration | none>

<Optional: 1-2 sentences of context>

Backlog Items:

* <ID>. <Title>
```

## Required Fields

| Field | Values | Default |
|-------|--------|---------|
| Status | `Planned`, `Progress`, `Done` | `Planned` |
| Mode | `managed`, `YOLO` | `managed` |
| Test | `smoke`, `unit`, `integration`, `none` | `unit, integration` |
| Regression | `smoke`, `unit`, `integration`, `none` | `unit, integration` |

## Validation

Before saving, verify:

| Check | Rule |
|-------|------|
| Sprint N | Sequential, no gaps |
| Status | Valid value |
| Mode | Valid value |
| Test | Required, valid values |
| Regression | Required, valid values |
| Items exist | All IDs must exist in BACKLOG.md |
| No duplicates | Item cannot be in multiple active sprints |

## Status Transitions

```
Planned → Progress → Done
                  → Failed
```

- `Planned → Progress`: When `/sprint start` or `/rup-manager` begins
- `Progress → Done`: When `/sprint close` after all gates pass
- `Progress → Failed`: When quality gates fail after retries exhausted
