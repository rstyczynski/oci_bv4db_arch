# Sprint 14 Design

Status: tested

Mode:

- `YOLO`

Scope:

- complete `BV4DB-36` by automating Oracle Database Free performance workload execution
- complete `BV4DB-38` by automating AWR snapshot window capture for database benchmarks
- complete `BV4DB-39` by automating AWR report export and archival for benchmark runs
- turn the Sprint 13 database host into a real benchmark target
- produce durable AWR artifacts that survive infrastructure teardown

Design choices:

- use simple SQL-based workload for Sprint 14 (Swingbench standardization deferred to Sprint 15)
- workload creates test schema, populates data, runs mixed read/write operations
- AWR snapshots bracketed around workload execution (begin snapshot before, end snapshot after)
- AWR report generated as HTML for portability and readability
- all artifacts copied to local progress directory before teardown
- reuse Sprint 13 infrastructure provisioning patterns
- keep infrastructure minimal (2 OCPUs, 16 GB, single block volume)

Implementation approach:

- create `run_oracle_workload.sh` script for automated workload execution
- create `capture_awr_snapshot.sh` script for AWR snapshot management
- create `export_awr_report.sh` script for AWR HTML report generation
- create `run_oracle_db_sprint14.sh` wrapper for complete Sprint 14 execution
- workload runs for configurable duration (default 5 minutes)
- AWR report covers exact workload window using captured snapshot IDs

Workload design:

- create BENCHMARK schema in FREEPDB1
- create ORDERS table with typical OLTP structure
- populate initial data set
- run concurrent INSERT/UPDATE/SELECT operations
- use PL/SQL procedure for repeatable execution
- capture timing and operation counts

AWR artifacts:

- `awr_begin_snap_id.txt` - starting snapshot ID
- `awr_end_snap_id.txt` - ending snapshot ID
- `awr_report.html` - AWR report for workload window
- `workload_results.log` - workload execution output
