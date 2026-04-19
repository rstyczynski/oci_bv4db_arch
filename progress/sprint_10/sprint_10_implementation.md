# Sprint 10 Implementation

Status: tested

YOLO decision log:

- Ambiguity: how to map OCI performance tiers onto the separated Oracle layout.
  Assumption: for tier-comparison purposes, use the same tier across DATA, REDO, and FRA volumes in the separated-volume runs.
  Rationale: this keeps the tier signal clean instead of mixing OCI performance classes inside one comparison run.
  Risk: medium.

- Ambiguity: how to size compute for non-UHP tiers.
  Assumption: use `2 OCPUs` for Lower Cost and `8 OCPUs` for Balanced and Higher Performance VM runs.
  Rationale: OCI documentation ties VM realization of block volume performance to OCPU count, and `8 OCPUs` is the meaningful threshold called out for Balanced and Higher Performance/UHP behavior.
  Risk: medium.

Execution summary:

- completed Lower Cost single-volume Oracle-style run
- completed Balanced single-volume Oracle-style run
- completed Balanced multi-volume Oracle-style run
- completed Higher Performance single-volume Oracle-style run
- completed Higher Performance multi-volume Oracle-style run
- preserved Sprint 9 as the UHP reference point for single-volume and multi-volume UHP layouts
- added aggregated logical-volume reporting and the Sprint 10 OCI tier comparison document

Practical result:

- Lower Cost is only a minimal Oracle starting point.
- Balanced single-volume is operationally simple but keeps `DATA`, `REDO`, and `FRA` in one contention domain.
- Balanced multi-volume is the first production-style OCI Oracle layout in this repository with reasonable `DATA` and strong synchronous `REDO`.
- Higher Performance multi-volume is the strongest non-UHP result proven by Sprint 10.
