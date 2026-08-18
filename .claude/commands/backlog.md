# /backlog — Backlog Management

Manage product backlog items in `BACKLOG.md`.

## Usage

```
/backlog add <title>
/backlog list [--status <new|ready|in-progress|done>]
/backlog prioritize
```

## Operations

### add

Create a new backlog item following the defined format.

**Steps:**
1. Read `BACKLOG.md` to find the next available ID (auto-detect prefix from existing items)
2. Ask user for:
   - Title (one short sentence, max 80 chars)
   - Description (2-4 sentences: what, why, key constraint)
   - Test criterion (one line: how to know it works)
3. Validate against constraints from `rules/generic/backlog_item_definition.md`
4. Append to `BACKLOG.md`
5. Update `PROGRESS_BOARD.md` with status "New"

### list

Display backlog items, optionally filtered by status.

**Steps:**
1. Read `BACKLOG.md`
2. Read `PROGRESS_BOARD.md` for status
3. Display items in table format (filtered if status provided)

### prioritize

Interactive reordering of backlog items.

**Steps:**
1. Read `BACKLOG.md`
2. Show current order with status
3. Ask user for new priority order
4. Rewrite `BACKLOG.md` with new order

---

## Format

See `rules/generic/backlog_item_definition.md` for full specification.

```markdown
### <ID>. <Title>

<2-4 sentences: what, why, constraint>

Test: <one line — how to know it works>
```

## Constraints

- No design decisions, architecture, or implementation steps
- No tables or bullet lists of sub-tasks
- Small enough to hold in your head
- Detail belongs in sprint elaboration, not backlog

## Validation

Before saving, verify:

| Check | Rule |
|-------|------|
| Title | Max 80 characters |
| Description | 2-4 sentences only |
| Test line | Single line, starts with verb |
| No design | No tables, bullet lists, code blocks, file paths |
| Atomic | Single feature per item |

## ID Convention

- Generic: `PBI-001`, `PBI-002`
- Project-specific: Auto-detect prefix from existing items (e.g., `SLI-`, `GH-`)
