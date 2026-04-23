# Sprint 17 Design

Status: tested

Mode:

- `YOLO`

Scope:

- complete `BV4DB-44` by running a consolidated benchmark on a multi-volume Oracle-style topology with a UHP-sized compute profile
- execute two benchmark phases on the same topology: `fio` first, then Oracle Database Free `Swingbench`
- collect guest `iostat` and OCI metrics for both phases
- preserve the existing AWR capture and export path for the Swingbench phase
- emit standalone HTML artifacts for `fio`, `Swingbench`, and `AWR`
- finish with an integrated summary artifact that explains what Sprint 17 proves in the context of the project so far

Feasibility:

- the repository already has a working Oracle-style multi-volume `fio` path from the earlier storage sprints
- the repository already has a working Oracle Database Free install plus `Swingbench` path from Sprint 13 to Sprint 15
- the OCI metrics Markdown and HTML reporting path already exists and can be reused by constructing phase-specific metrics state files
- the missing piece for Sprint 17 is one orchestrator that keeps the same topology alive across both phases and emits one consolidated result set

YOLO decisions:

1. reuse the established Oracle-style multi-volume storage split with `2x DATA`, `2x REDO`, and `1x FRA` instead of inventing a new storage topology for the summary sprint
2. treat a `VM.Standard.E5.Flex` instance with `40 OCPUs` and `64 GB` RAM as the UHP-sized compute profile for this sprint because that is already aligned with the higher-end Oracle fio work in earlier sprints
3. reuse the existing `progress/sprint_10/oracle-layout-4k-redo.fio` workload profile for the FIO phase so the summary sprint stays comparable with the validated Oracle fio baseline
4. keep the Sprint 15 `Swingbench` benchmark definition as the database-level phase and add guest `iostat` capture around it instead of replacing the benchmark model
5. generate a new dedicated FIO HTML report so the Sprint 17 operator artifact set has the same level of readability as the Swingbench and OCI metrics outputs
6. accept `VM.Standard.E5.Flex` capacity fallback from `40 OCPUs` to `20 OCPUs / 64 GB` when OCI reported host-capacity exhaustion, because the sprint goal is the integrated benchmark flow and not strict shape reservation behavior

Implementation approach:

- add `tools/run_oracle_db_sprint17.sh` as the combined Sprint 17 orchestrator
- reuse the hardened remote-step execution approach from Sprint 15 for long remote operations
- provision the multi-volume Oracle topology once and keep it for both phases
- run the FIO phase with guest `iostat`, then collect OCI metrics for the exact FIO phase window
- install Oracle Database Free on the same host and layout, then run the Swingbench phase with guest `iostat`, OCI metrics, and AWR
- render a standalone FIO HTML dashboard from the archived fio and `iostat` artifacts
- reuse the existing Swingbench HTML renderer and OCI metrics HTML renderer for the database phase
- write an integrated Sprint 17 summary that links all phase reports together

### Testing Strategy

#### Recommended Sprint Parameters

- **Test:** integration — Sprint 17 adds a new end-to-end benchmark orchestrator and report set
- **Regression:** integration — the new sprint builds on existing Oracle benchmark and metrics-reporting paths

#### Integration Test Scenarios

| Scenario | Infrastructure Dependencies | Expected Outcome | Est. Runtime |
|----------|----------------------------|------------------|--------------|
| Sprint 17 repository contract validation | local repo only | scripts, docs, and report wiring exist and parse correctly | < 5 sec |
| Sprint 17 live benchmark execution | OCI tenancy, Sprint 1 infra state, Oracle package download path | the two-phase benchmark completes and archives the expected report set | tens of minutes |

## Test Specification

Sprint Test Configuration:
- Test: integration
- Mode: YOLO

### Integration Tests

#### IT-65: Sprint 17 documentation exists
- **Preconditions:** repository checkout contains Sprint 17 artifacts
- **Steps:** verify design, implementation, tests, summary, and manual files are present
- **Expected Outcome:** Sprint 17 documentation is committed and references `BV4DB-44` and `BV4DB-45`
- **Verification:** `tests/integration/test_oracle_db_sprint17.sh`

#### IT-66: Sprint 17 scripts exist and are executable
- **Preconditions:** repository checkout contains Sprint 17 scripts
- **Steps:** verify the Sprint 17 runner and report renderer scripts exist and are executable
- **Expected Outcome:** operator-facing Sprint 17 scripts are runnable
- **Verification:** `tests/integration/test_oracle_db_sprint17.sh`

#### IT-67: Sprint 17 runner wires both phases and metrics
- **Preconditions:** repository checkout contains Sprint 17 scripts
- **Steps:** inspect the sprint runner for `fio`, `Swingbench`, `AWR`, and `operate-metrics` calls
- **Expected Outcome:** the sprint runner orchestrates both benchmark phases and metrics collection without a parallel one-off path
- **Verification:** `tests/integration/test_oracle_db_sprint17.sh`

#### IT-68: Sprint 17 report artifacts exist
- **Preconditions:** Sprint 17 result artifacts exist in `progress/sprint_17`
- **Steps:** verify the FIO HTML report, Swingbench HTML report, AWR HTML report, OCI metrics HTML reports, and summary artifact are present
- **Expected Outcome:** the consolidated benchmark sprint produces the operator-facing report set promised by the sprint definition
- **Verification:** `tests/integration/test_oracle_db_sprint17.sh`

## Execution Result

- Sprint 17 completed in fully automated mode on `2026-04-23`
- live execution used `FIO_RUNTIME_SEC=60` and `SWINGBENCH_WORKLOAD_DURATION=60`
- OCI host capacity was not available for the requested `40 OCPU` profile, so the runner auto-selected the fallback `20 OCPUs / 64 GB`
- the unattended path completed through both benchmark phases, OCI metrics collection, AWR export, artifact copy-back, summary generation, and infrastructure teardown

### Traceability

| Backlog Item | Integration Tests |
|--------------|-------------------|
| BV4DB-44 | IT-65, IT-66, IT-67, IT-68 |
| BV4DB-45 | IT-65, IT-68 |
