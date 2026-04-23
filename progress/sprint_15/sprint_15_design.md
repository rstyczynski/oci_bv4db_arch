# Sprint 15 Design

Status: tested

Mode:

- `managed`

Scope:

- complete `BV4DB-41` by standardizing `Swingbench` as the Oracle Database Free load generator
- complete `BV4DB-42` by adding an HTML presentation layer for archived Swingbench results
- complete `BV4DB-43` by moving the active Swingbench workload configuration into a project-owned XML file
- preserve the Sprint 14 AWR capture path so future workload scenarios stay comparable
- make load generation runnable through one stable Oracle benchmark flow instead of the temporary SQL-only workload from Sprint 14
- keep `HammerDB` explicitly documented as the fallback tool when `Swingbench` is proven unsuitable for a scenario

Feasibility:

- `Swingbench` is suitable for this sprint because its maintained public release provides `oewizard` for schema creation and `charbench` for CLI load generation
- the current public build requires Java 17 or later and ships a CLI-oriented execution path that fits the repository automation model
- `HammerDB` remains feasible as a fallback because it has an official CLI path and Linux release artifacts, but this sprint does not need a second automated benchmark harness unless `Swingbench` fails the required scenario

Design choices:

- replace the ad hoc SQL benchmark path from Sprint 14 with a `Swingbench` SOE workload
- keep the benchmark host provisioning, Oracle Database Free installation, and AWR collection flow aligned with Sprint 14
- install `Swingbench` directly on the remote benchmark host during the run so the operator can rerun load generation without manual packaging steps
- export both file-based `Swingbench` results and the latest `BENCHMARK_RESULTS` database row for later comparison work
- generate a self-contained local HTML dashboard from archived Swingbench XML, CLI log, and JSON artifacts after they are copied back to the repository
- keep the active Swingbench workload definition in `config/swingbench/` and upload that exact file during benchmark execution
- include a documented `HammerDB` installer so fallback activation is explicit and repeatable when needed

Implementation approach:

- add `tools/install_swingbench.sh` to install the current public `Swingbench` build with Java 17
- add `tools/run_oracle_swingbench.sh` to create the SOE schema and run `charbench`
- add `tools/install_hammerdb.sh` as the documented fallback installer
- add `tools/render_swingbench_report_html.sh` to render a standalone HTML dashboard from archived Swingbench artifacts
- add `config/swingbench/SOE_Server_Side_V2.xml` as the project-owned benchmark configuration file
- add `tools/run_oracle_db_sprint15.sh` to provision the host, install Oracle Database Free, run `Swingbench`, capture AWR, archive artifacts, and tear down the infrastructure
- keep Sprint 14 untouched so the earlier temporary workload path remains auditable

### Testing Strategy

#### Recommended Sprint Parameters

- **Test:** integration — Sprint 15 adds a new end-to-end benchmark runner and operator workflow
- **Regression:** integration — the sprint extends the Oracle benchmark path and should keep the recent Oracle sprint scripts valid

#### Integration Test Scenarios

| Scenario | Infrastructure Dependencies | Expected Outcome | Est. Runtime |
|----------|----------------------------|------------------|--------------|
| Sprint 15 repository contract validation | local repo only | docs, scripts, and runner wiring exist and parse correctly | < 5 sec |
| Sprint 15 live benchmark execution | OCI tenancy, Sprint 1 infra state, Oracle Database Free install path | Swingbench run produces artifacts plus AWR report | several minutes |

## Test Specification

Sprint Test Configuration:
- Test: integration
- Mode: managed

### Integration Tests

#### IT-59: Sprint 15 documentation exists
- **Preconditions:** repository checkout contains Sprint 15 artifacts
- **Steps:** verify design, implementation, tests, and `sprint15_manual.md` are present
- **Expected Outcome:** Sprint 15 documentation is committed and references `BV4DB-41`
- **Verification:** `tests/integration/test_oracle_db_sprint15.sh`

#### IT-60: Sprint 15 scripts are executable
- **Preconditions:** repository checkout contains Sprint 15 scripts
- **Steps:** verify installer, workload runner, and sprint wrapper are executable
- **Expected Outcome:** operator-facing scripts are runnable
- **Verification:** `tests/integration/test_oracle_db_sprint15.sh`

#### IT-61: Sprint 15 scripts pass bash syntax validation
- **Preconditions:** shell environment with `bash`
- **Steps:** run `bash -n` against the new Sprint 15 scripts
- **Expected Outcome:** no syntax errors are present in the new automation path
- **Verification:** `tests/integration/test_oracle_db_sprint15.sh`

#### IT-62: Sprint 15 runner wires Swingbench and AWR
- **Preconditions:** repository checkout contains Sprint 15 scripts
- **Steps:** inspect the sprint wrapper and workload runner for `Swingbench`, `BENCHMARK_RESULTS`, and AWR calls
- **Expected Outcome:** the workflow is standardized on `Swingbench` while preserving AWR capture
- **Verification:** `tests/integration/test_oracle_db_sprint15.sh`

#### IT-63: Sprint 15 HTML report exists and contains benchmark sections
- **Preconditions:** Sprint 15 result artifacts exist in `progress/sprint_15`
- **Steps:** verify the HTML report exists and contains overview, runtime chart, and transaction sections
- **Expected Outcome:** archived Swingbench results are readable through a standalone HTML dashboard
- **Verification:** `tests/integration/test_oracle_db_sprint15.sh`

#### IT-64: Sprint 15 uses a project-owned Swingbench config file
- **Preconditions:** repository checkout contains Sprint 15 scripts and config
- **Steps:** verify the project config XML exists, the runner uploads it, and the archived sprint artifacts include the used config file
- **Expected Outcome:** the benchmark definition is versioned in the project and archived with the run artifacts
- **Verification:** `tests/integration/test_oracle_db_sprint15.sh`

### Traceability

| Backlog Item | Integration Tests |
|--------------|-------------------|
| BV4DB-41 | IT-59, IT-60, IT-61, IT-62 |
| BV4DB-42 | IT-59, IT-63 |
| BV4DB-43 | IT-59, IT-64 |
