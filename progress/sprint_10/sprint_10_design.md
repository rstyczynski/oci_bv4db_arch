# Sprint 10 Design

Status: tested

Mode:

- `YOLO`

Scope:

- keep the Sprint 9 `4k` redo fio workload unchanged
- compare OCI Lower Cost, Balanced, Higher Performance, and existing UHP evidence
- run single-volume and separated-volume variants where required by backlog
- adjust compute OCPU count to the targeted OCI volume performance level

Design choices:

- single-volume Lower Cost uses `0` VPU/GB
- Balanced uses `10` VPU/GB
- Higher Performance uses `20` VPU/GB
- existing UHP evidence remains Sprint 9
- compute sizing starts at `2 OCPUs` for Lower Cost and `8 OCPUs` for Balanced/Higher Performance to stay aligned with OCI block volume guidance for realizing tier performance on VM instances
