# Sprint 5 - Design

## BV4DB-10. Reexecute Oracle-style layout with corrected fio job reporting

Status: Accepted

## Goal

Reexecute the Sprint 4 Oracle-style five-volume layout with a corrected fio profile so that fio emits distinct per-job results for `data-8k`, `redo`, and `fra-1m`.

## Execution Mode

- Sprint 5 runs in `YOLO` mode.
- Reason: this sprint is an exact Sprint 4 rerun at infrastructure level and changes only the fio workload definition file.
- Reused from Sprint 4:
  - topology
  - runner approach
  - `iostat`-based isolation validation approach
  - teardown approach

## Scope

- reuse the Sprint 4 topology:
  - 2x UHP data volumes striped to `/u02/oradata`
  - 2x HP redo volumes striped to `/u03/redo`
  - 1x FRA volume mounted at `/u04/fra`
- reuse Sprint 4 design and validation logic unless directly affected by the corrected fio profile
- replace the Sprint 4 fio profile with the corrected Sprint 5 profile committed in `progress/sprint_5/oracle-layout.fio`
- produce valid per-job fio JSON artifacts
- validate device-level isolation with `iostat`

## Corrective Change

Sprint 4 failed because `group_reporting=1` collapsed concurrent job reporting into an aggregated fio result.

Sprint 5 fixes that by using:

- `group_reporting=0`
- `runtime=600`
- `ramp_time=60`
- revised redo workload: `bs=512`, `fdatasync=1`
- revised FRA workload: `rw=readwrite`, `numjobs=1`, `iodepth=8`, `rate=120M`

## Artifacts

- `progress/sprint_5/oracle-layout.fio`
- `progress/sprint_5/fio-results-oracle.json`
- `progress/sprint_5/iostat-oracle.json`
- `progress/sprint_5/fio-analysis-oracle.md`
