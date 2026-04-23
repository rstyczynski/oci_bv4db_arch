# Sprint 15 Tests

## Integration Tests

### IT-59: Sprint 15 documentation exists

Validates that Sprint 15 documentation is present and references the standardized load-generator decision.

### IT-60: Sprint 15 scripts exist and are executable

Validates that the new installer and benchmark scripts are runnable by the operator.

### IT-61: Sprint 15 scripts pass bash syntax validation

Validates that the new automation path has no shell syntax errors.

### IT-62: Sprint 15 runner wires Swingbench and AWR

Validates that the Sprint 15 wrapper invokes `Swingbench` and preserves AWR capture/export.

### IT-63: Sprint 15 HTML report exists and contains benchmark sections

Validates that Sprint 15 produces an HTML dashboard for the archived Swingbench results.

### IT-64: Sprint 15 uses a project-owned Swingbench config file

Validates that the benchmark definition is stored in the repository and archived with the sprint artifacts.

## Executed Gate

- `A3 integration`: `progress/sprint_15/test_run_A3_integration_20260423_120409.log`
- `B3 integration`: `progress/sprint_15/test_run_B3_integration_20260423_120409.log`
- `A3 integration rerun`: `progress/sprint_15/test_run_A3_integration_20260423_163640.log`

## Results

- `A3 integration` passed with `6` checks passing and `0` failures after the HTML-report and project-config additions
- the Sprint 15 result set now includes the project-owned `swingbench_config.xml` artifact
- `B3 integration` passed with Sprint 13, Sprint 14, and Sprint 15 integration checks all green
- `A3 integration rerun` passed after the live config-backed rerun and confirms the archived config matches the project-owned XML
- live Sprint 15 OCI benchmark rerun completed successfully on `2026-04-23` with the repository-owned config and produced archived `Swingbench` plus AWR artifacts in `progress/sprint_15`
- the archived Sprint 15 result set now includes `swingbench_report.html`
- the live rerun captured AWR snapshots `1 -> 2`
- the live rerun archived `449863` completed transactions, `0` failures, and `1499.54` average TPS
