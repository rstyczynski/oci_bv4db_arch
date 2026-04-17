# Sprint 3 - Setup

## Contract

### Sprint Overview

Sprint 3 delivers the mixed `8k` fio profile benchmark on top of the Sprint 2 UHP compute and block volume topology. The workload must be executed from a fio profile file, starting with the `60`-second smoke run and preserving the `15`-minute integration run as the longer execution level.

### Rules Confirmed

- `GENERAL_RULES.md`: understood — work only against backlog items assigned to the active sprint, keep artifacts in sprint-local files.
- `GIT_RULES.md`: understood — semantic commit format `type: (sprint-N) message`.
- `backlog_item_definition.md`: understood — backlog item defines the requirement, not the implementation details.
- `sprint_definition.md`: understood — Sprint 3 is `managed`, `Test: integration`, `Regression: integration`.
- `AGENTS.md`: understood — `RUPStrikesBack/` is read-only; `oci_scaffold` changes must stay on branch `oci_bv4db_arch`.

### Responsibilities

- MAY edit: `progress/sprint_3/*`, `tests/*`, `tools/*`, `PLAN.md`, `PROGRESS_BOARD.md`, `BACKLOG.md`
- MAY edit in submodule branch: `oci_scaffold/*`
- MUST NOT edit: `RUPStrikesBack/*`

### Status

Contracting complete — Sprint 3 execution started.
