# Sprint 8 Implementation

Status: tested

Sprint 8 was started in YOLO mode immediately after backlog and sprint creation.

YOLO decision log:

- Ambiguity: whether "start the sprint now" means planning only or actual execution start.
  Assumption: create the Sprint 8 artifacts, set the sprint to `Progress`, and begin execution state immediately.
  Rationale: the user explicitly asked to add the sprint and start it now.
  Risk: low.

- Ambiguity: whether the Sprint 5 fio workload should remain structurally unchanged or be adapted to a single mount point.
  Assumption: keep the Sprint 5 fio job unchanged in intent and structure, while changing only the underlying storage topology to a single UHP volume.
  Rationale: the user clarified that the same compute shape and the same fio job must be used, and that the only intended difference is a single block volume.
  Risk: low.

- Ambiguity: whether Sprint 8 may change the compute shape from Sprint 5.
  Assumption: reuse the Sprint 5 compute shape exactly.
  Rationale: the user explicitly clarified that the compute shape stays the same.
  Risk: low.

- Ambiguity: whether filesystem and LVM layout may be simplified together with the storage topology.
  Assumption: keep the Sprint 5 filesystem layout and LVM structure unchanged, with only the underlying block volume topology reduced to one UHP volume.
  Rationale: the user explicitly clarified that the filesystem and LVM must remain the same.
  Risk: low.

Execution notes:

- The reusable Oracle runner was extended with `STORAGE_LAYOUT_MODE=single_uhp` so Sprint 8 could reuse the Sprint 5 fio workload and compute shape while changing only the underlying block volume topology.
- The first guest-layout attempt failed because `sfdisk` refused repartitioning a live multipath device without `--force`.
- A second attempt exposed a real layout issue: DOS/MBR partitioning only created four usable partitions, which was insufficient for the required `data1`, `data2`, `redo1`, `redo2`, and `fra` slices.
- The final working layout used GPT partitioning on the single UHP multipath device and recreated the same guest-visible topology as Sprint 5:
  - `vg_data/lv_oradata` striped across partitions `1` and `2`
  - `vg_redo/lv_redo` striped across partitions `3` and `4`
  - direct FRA mount on partition `5`
- After the layout fix, the integration fio run completed successfully and produced valid per-job JSON plus `iostat` capture.
