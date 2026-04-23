# Sprint 17 Tests

Status: passed

## Integration Tests

### IT-65: Sprint 17 documentation exists

Validates that Sprint 17 design, implementation, tests, summary, and manual artifacts exist and reference the consolidated benchmark scope.

### IT-66: Sprint 17 scripts exist and are executable

Validates that the Sprint 17 runner and new report renderer are present and runnable by the operator.

### IT-67: Sprint 17 runner wires both phases and metrics

Validates that the Sprint 17 orchestrator contains both the `fio` and `Swingbench` phases, AWR capture, and OCI metrics collection/report generation.

### IT-68: Sprint 17 report artifacts exist

Validates that the consolidated benchmark sprint produces the promised FIO, Swingbench, AWR, OCI metrics, and summary artifacts.

## Executed Validation

- Live benchmark execution completed on `2026-04-23`
- Executed parameters: `FIO_RUNTIME_SEC=60`, `SWINGBENCH_WORKLOAD_DURATION=60`
- Integration gate command: `bash tests/integration/test_oracle_db_sprint17.sh`
- Result: `4 passed, 0 failed`
- Test log: `progress/sprint_17/test_run_A3_integration_20260423_163328.log`

## Verified operator outputs

- `fio_report.html`
- `fio_oci_metrics_report.html`
- `swingbench_report.html`
- `swingbench_oci_metrics_report.html`
- `awr_report.html`
- `sprint_17_summary.md`
