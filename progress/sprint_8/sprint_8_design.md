# Sprint 8 Design

Status: approved

## BV4DB-15. Run the Sprint 5 Oracle fio job on a single UHP block volume

Sprint 8 compares the Oracle-style workload from Sprint 5 against a simpler topology based on one Ultra High Performance block volume. The compute shape, fio job, filesystem layout, and LVM model remain the same as Sprint 5; the only intended difference is that all storage is backed by one single UHP block volume instead of separate underlying volumes for isolated `DATA`, `REDO`, and `FRA` domains.

Because Sprint 8 runs in YOLO mode, the sprint starts immediately after design creation. The practical objective is to generate directly comparable artifacts showing how the single-UHP-volume layout behaves relative to the split-domain Oracle-style layout.

Assumptions for Sprint 8:

- shared infrastructure from earlier sprints remains reusable
- the Sprint 5 compute shape is reused without change
- the Sprint 5 fio workload file is reused without change
- the Sprint 5 filesystem layout is reused without change
- the Sprint 5 LVM model is reused without change
- the only topology change is replacement of the split underlying block volume set with a single UHP block volume
- the single-volume comparison is meaningful even though the storage-domain isolation is intentionally removed
