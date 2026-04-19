# Sprint 9 Implementation

Status: tested

YOLO decision log:

- Ambiguity: whether Sprint 9 should create new topology logic or reuse the proven Sprint 5 and Sprint 8 Oracle paths.
  Assumption: reuse the proven Oracle runner and wrappers, and change only what is needed for the `4k` redo variant and artifact separation.
  Rationale: the user explicitly asked for exact copies of Sprint 5 and Sprint 8 except for the redo block size and requested script unification.
  Risk: low.

- Ambiguity: whether both runs should remain in one sprint directory.
  Assumption: keep both runs in `progress/sprint_9/` and differentiate them with explicit artifact prefixes.
  Rationale: this keeps comparison straightforward and matches the single-sprint request.
  Risk: low.

Execution summary:

- the Oracle fio runner was polished to support explicit artifact prefixes so multiple Oracle variants can be executed in one sprint without file collisions
- the same shared runner path was used successfully for both the single-UHP and separated-volume `4k` redo runs
- the single-UHP `4k` redo run completed, produced artifacts, and tore down cleanly
- the separated-volume `4k` redo run completed, produced artifacts, and tore down cleanly

Observed result:

- single UHP remained constrained by shared-device contention even after the redo block size moved to `4k`
- separated volumes benefited materially from the `4k` redo profile and remained the stronger Oracle-style topology
