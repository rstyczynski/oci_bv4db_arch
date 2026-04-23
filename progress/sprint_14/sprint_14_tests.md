# Sprint 14 Tests

## Integration Tests

### IT-14-01: Automated Workload Execution

Validates that database workload runs automatically without manual intervention.

**Criteria:**
- Workload script executes without errors
- BENCHMARK schema created in FREEPDB1
- ORDERS table populated with test data
- Mixed INSERT/UPDATE/SELECT operations complete
- Workload results logged to artifact file

### IT-14-02: AWR Snapshot Capture

Validates that AWR snapshots bracket the workload window.

**Criteria:**
- Begin snapshot captured before workload
- End snapshot captured after workload
- Snapshot IDs recorded to artifact files
- Snapshots exist in DBA_HIST_SNAPSHOT

### IT-14-03: AWR Report Export

Validates that AWR report is generated and archived.

**Criteria:**
- AWR report generated as HTML
- Report covers exact workload window (begin to end snapshot)
- Report file copied to local progress directory
- Report is readable after infrastructure teardown

### IT-14-04: Artifact Completeness

Validates that all benchmark artifacts are produced.

**Criteria:**
- workload_results.log exists and contains execution data
- awr_begin_snap_id.txt exists and contains valid snapshot ID
- awr_end_snap_id.txt exists and contains valid snapshot ID
- awr_report.html exists and contains AWR content
