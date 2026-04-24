# Sprint 18 Design

Status: in_progress

Mode:

- `YOLO`

Scope:

- complete `BV4DB-46` as an exact mirror rerun of Sprint 17
- keep the same Oracle-style multi-volume UHP benchmark topology
- keep the same `fio` phase, `Swingbench` phase, guest `iostat`, OCI metrics, Swingbench HTML, and AWR export flow
- change only the benchmark durations to `900` seconds for both phases so the archived evidence is benchmark-quality and not only orchestration validation

YOLO decisions:

1. reuse the Sprint 17 runner as the implementation base and add a thin Sprint 18 wrapper rather than creating a second divergent orchestrator
2. keep the same capacity-fallback behavior as Sprint 17 because OCI host-capacity behavior is an environmental constraint, not a Sprint 18 design variable
3. treat non-trivial Swingbench-phase OCI block-volume metrics as a success criterion for the rerun because that is the core reason Sprint 18 exists

Implementation approach:

- add a Sprint 18 wrapper script that invokes the Sprint 17 runner with Sprint 18 identity and `900s` durations
- keep all outputs in `progress/sprint_18`
- rerun the benchmark live and archive the resulting `fio`, `Swingbench`, OCI metrics, and AWR outputs
- validate the resulting artifact set with a dedicated Sprint 18 integration test

### Testing Strategy

#### Recommended Sprint Parameters

- **Test:** integration
- **Regression:** integration

### Integration Tests

#### IT-72: Sprint 18 documentation exists
- **Preconditions:** repository checkout contains Sprint 18 artifacts
- **Steps:** verify design, implementation, tests, summary, and manual files are present
- **Expected Outcome:** Sprint 18 documentation is committed and references `BV4DB-46`
- **Verification:** `tests/integration/test_oracle_db_sprint18.sh`

#### IT-73: Sprint 18 wrapper enforces mirror-run parameters
- **Preconditions:** repository checkout contains Sprint 18 runner
- **Steps:** inspect the wrapper for Sprint 18 progress path, name prefix, and `900`-second phase settings
- **Expected Outcome:** Sprint 18 is an exact Sprint 17 mirror run except for phase duration and sprint identity
- **Verification:** `tests/integration/test_oracle_db_sprint18.sh`

#### IT-74: Sprint 18 report artifacts exist
- **Preconditions:** Sprint 18 result artifacts exist in `progress/sprint_18`
- **Steps:** verify the FIO HTML report, Swingbench HTML report, AWR HTML report, OCI metrics HTML reports, and summary artifact are present
- **Expected Outcome:** the `900s` mirror rerun produces the same benchmark artifact contract as Sprint 17
- **Verification:** `tests/integration/test_oracle_db_sprint18.sh`
