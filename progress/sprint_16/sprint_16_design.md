# Sprint 16 Design

Status: failed

Mode:

- `yolo`

Scope:

- complete `BV4DB-37` by comparing Oracle Database Free benchmark evidence with the existing `fio` baseline evidence already archived in the repository
- complete `BV4DB-40` by correlating AWR findings with guest observations and OCI metrics from the same benchmark window
- reuse archived Sprint 10, Sprint 12, Sprint 15, and Sprint 17 artifacts instead of provisioning new infrastructure when the required evidence already exists

Feasibility:

- Sprint 15 already provides a completed Oracle Database Free `Swingbench` run with AWR and a project-owned workload definition
- Sprint 17 already provides a completed two-phase run with `fio`, `Swingbench`, guest `iostat`, OCI metrics, and AWR
- Sprint 10 and Sprint 12 already provide the storage-only Oracle-style `fio` baselines needed to explain what the database benchmark adds beyond synthetic I/O

YOLO decisions:

1. treat Sprint 16 as an evidence-correlation sprint and do not rerun OCI infrastructure unless a required source artifact is actually missing
2. use Sprint 17 as the primary correlation dataset because it is the only archived run that contains `fio`, `Swingbench`, guest `iostat`, OCI metrics, and AWR on one comparable topology
3. use Sprint 15 as the standardized single-volume `Swingbench` reference because it is the longest validated database run in the repository and uses the project-owned Swingbench config
4. use Sprint 10 Higher Performance and UHP `fio` baselines to explain how far storage-only evidence can go before database-level instrumentation becomes necessary

Retrospective failure note:

- Sprint 16 should have added a hard validation step that fails when Swingbench guest `iostat` and OCI metrics do not show sustained activity on the attached data block volumes

Implementation approach:

- add Sprint 16 documentation artifacts under `progress/sprint_16`
- write a consolidated analysis document that references concrete Sprint 10, Sprint 12, Sprint 15, and Sprint 17 results
- add an integration test that fails if the required source artifacts from Sprint 15 or Sprint 17 disappear
- update the sprint plan and progress board when the analysis and test gate are complete

### Testing Strategy

#### Recommended Sprint Parameters

- **Test:** integration
- **Regression:** integration

#### Integration Test Scenarios

| Scenario | Infrastructure Dependencies | Expected Outcome | Est. Runtime |
|----------|----------------------------|------------------|--------------|
| Sprint 16 repository evidence validation | local repo only | Sprint 16 analysis exists and references archived Sprint 15 and Sprint 17 evidence | < 5 sec |
| Sprint 16 regression evidence validation | local repo only | required Sprint 15 and Sprint 17 source artifacts still exist and remain testable | < 5 sec |

## Test Specification

Sprint Test Configuration:
- Test: integration
- Mode: yolo

### Integration Tests

#### IT-69: Sprint 16 documentation exists
- **Preconditions:** repository checkout contains Sprint 16 artifacts
- **Steps:** verify design, implementation, tests, summary, analysis, and manual files are present
- **Expected Outcome:** Sprint 16 documentation is committed and references `BV4DB-37` and `BV4DB-40`
- **Verification:** `tests/integration/test_oracle_db_sprint16.sh`

#### IT-70: Sprint 16 analysis references required source evidence
- **Preconditions:** archived Sprint 10, Sprint 15, and Sprint 17 artifacts exist
- **Steps:** verify the analysis document references the expected source artifacts and comparison topics
- **Expected Outcome:** Sprint 16 is grounded in archived benchmark evidence and not in speculative claims
- **Verification:** `tests/integration/test_oracle_db_sprint16.sh`

#### IT-71: Sprint 16 required source artifacts exist
- **Preconditions:** Sprint 15 and Sprint 17 archived artifacts are present
- **Steps:** verify `Swingbench`, AWR, `fio`, and OCI metrics artifacts required by the analysis exist
- **Expected Outcome:** Sprint 16 fails fast if Sprint 15 or Sprint 17 archived evidence is missing
- **Verification:** `tests/integration/test_oracle_db_sprint16.sh`

### Traceability

| Backlog Item | Integration Tests |
|--------------|-------------------|
| BV4DB-37 | IT-69, IT-70, IT-71 |
| BV4DB-40 | IT-69, IT-70, IT-71 |
