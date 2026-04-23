# Sprint 14 Implementation

## YOLO Decision Log

1. **Workload type**: Simple SQL-based OLTP simulation (Swingbench deferred to Sprint 15)
2. **Workload duration**: 5 minutes default, configurable via environment variable
3. **AWR format**: HTML report for portability
4. **Database target**: FREEPDB1 (pluggable database from Sprint 13)
5. **Schema**: BENCHMARK schema with ORDERS table

## Execution Summary

Sprint 14 turns the Sprint 13 database foundation into a benchmark target by:

1. Provisioning compute + block volume + Oracle Database Free (reusing Sprint 13 patterns)
2. Creating benchmark schema and test data in FREEPDB1
3. Capturing AWR begin snapshot
4. Running automated OLTP workload for specified duration
5. Capturing AWR end snapshot
6. Generating AWR HTML report for workload window
7. Archiving all artifacts locally before teardown

## Scripts Created

- `tools/run_oracle_db_sprint14.sh` - Main sprint runner
- `tools/run_oracle_workload.sh` - Database workload execution
- `tools/capture_awr_snapshot.sh` - AWR snapshot management
- `tools/export_awr_report.sh` - AWR report generation

## Artifacts Produced

- `state-*.json` - Infrastructure state files
- `workload_results.log` - Workload execution output
- `awr_begin_snap_id.txt` - Starting snapshot ID
- `awr_end_snap_id.txt` - Ending snapshot ID
- `awr_report.html` - AWR report for benchmark window
- `db-status.log` - Database status verification

## User Documentation

See [sprint14_manual.md](sprint14_manual.md) for:

- Manual workload execution procedures
- AWR snapshot capture commands
- AWR report generation steps
- Artifact collection guide
