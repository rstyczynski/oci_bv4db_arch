# Sprint 14 Summary

## Infrastructure

- Compute: `VM.Standard.E5.Flex` (2 OCPUs, 16 GB RAM)
- Public IP: `152.67.88.172`
- Storage: Single block volume (600 GB, 10 VPU/GB)

## Benchmark Window

- Workload duration: `120 seconds`
- Begin Snapshot ID: `2`
- End Snapshot ID: `3`

## AWR Snapshots

| Snapshot | ID |
|----------|-----|
| Begin | 2 |
| End | 3 |

## Workload Summary

The benchmark workload executed successfully:
- Created BENCHMARK schema in FREEPDB1
- Created ORDERS table with OLTP structure
- Populated 10,000 initial orders
- Ran mixed INSERT/UPDATE/SELECT operations for 120 seconds
- Final operation counts available in `workload_results.log`

## Artifacts

| File | Description |
|------|-------------|
| `awr_report.html` | AWR report for benchmark window (snapshots 2-3) |
| `workload_results.log` | Workload execution output |
| `awr_begin_snap_id.txt` | Begin snapshot ID (2) |
| `awr_end_snap_id.txt` | End snapshot ID (3) |
| `db-status.log` | Database status verification |
| `db-install.log` | Database installation log |

## Validation Results

- [x] Workload executed automatically (BV4DB-36)
- [x] AWR begin snapshot captured (BV4DB-38)
- [x] AWR end snapshot captured (BV4DB-38)
- [x] AWR report generated and archived (BV4DB-39)
- [x] All artifacts collected before teardown

## Database Status

```
=== Instance Status ===
INSTANCE_NAME   STATUS          DATABASE_STATUS
--------------- --------------- -----------------
FREE            OPEN            ACTIVE

=== PDB Status ===
NAME                 OPEN_MODE
-------------------- ---------------
PDB$SEED             READ ONLY
FREEPDB1             READ WRITE
```

## Backlog Items Completed

### BV4DB-36: Automated Oracle Database Free performance workload execution

Oracle Database Free workload executed automatically without manual intervention. Workload creates BENCHMARK schema, populates test data, runs mixed INSERT/UPDATE/SELECT operations, and produces result artifacts.

**Test result**: PASS

### BV4DB-38: Automated AWR snapshot window capture for database benchmarks

AWR snapshots captured before and after workload execution. Snapshot IDs recorded to artifact files for reproducible analysis.

**Test result**: PASS

### BV4DB-39: Automated AWR report export and archival for benchmark runs

AWR HTML report generated for exact workload window (snapshots 2-3). Report archived locally and survives infrastructure teardown.

**Test result**: PASS
