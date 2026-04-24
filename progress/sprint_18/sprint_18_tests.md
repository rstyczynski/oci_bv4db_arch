# Sprint 18 Tests

Status: passed

## Integration Tests

### IT-72: Sprint 18 documentation exists

Validates that Sprint 18 design, implementation, tests, summary, and manual artifacts exist.

### IT-73: Sprint 18 wrapper enforces mirror-run parameters

Validates that Sprint 18 is wired as a Sprint 17 mirror run with `900`-second `fio` and `Swingbench` phases.

### IT-74: Sprint 18 report artifacts exist

Validates that the Sprint 18 rerun produces the same report set as Sprint 17.

### IT-75: Oracle DB install enforces project storage layout

Validates that the installer contains project-storage placement enforcement and no longer relies on the Oracle Free default configure path.

### IT-76: metrics path includes boot volume

Validates that the OCI metrics path can include the boot volume alongside attached block volumes.

## Artifacts

- `progress/sprint_18/test_run_A3_integration_20260424_002156.log`
