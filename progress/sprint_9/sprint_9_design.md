# Sprint 9 Design

Status: under_construction

Mode:

- `YOLO`

Scope:

- unify and polish the Oracle fio runner path based on the learnings from Sprints 4, 5, and 8
- execute a single-UHP Oracle-style run with the Sprint 8 topology and `4k` redo
- execute a separated-volume Oracle-style run with the Sprint 5 topology and `4k` redo

Design choices:

- keep the proven Oracle fio workload shape unchanged except for `redo bs=4k`
- reuse the same generic Oracle runner for both topology variants
- keep both Sprint 9 result sets under one sprint directory with distinct artifact prefixes
