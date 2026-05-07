# Sprint 24 - Tests

Status: Progress

## Planned Gates

- Test: integration
- Regression: integration

## Test Coverage

### Integration Tests (Local / Offline)

Test runner: `tests/integration/test_sprint24_oci_agent_multipath.sh`

- IT-24-01: Sprint 24 progress artifacts exist
- IT-24-02: Manual includes oracle references and verification sections
- IT-24-03: Sprint 24 scripts parse without errors (if present)

### Live Execution Tests (Requires OCI)

These tests require OCI infrastructure and SSH access.

- LIVE-24-01: Enable Block Volume Management plugin and confirm it is running
- LIVE-24-02: Create a multipath-enabled iSCSI attachment (UHP) per Oracle docs
- LIVE-24-03: Evidence checklist passes (sessions, mapper, mount source)
- LIVE-24-04: Archive evidence bundle under `progress/sprint_24/`

## Artifacts

Local/offline gates:

- A3 integration: PASS - `progress/sprint_24/test_run_A3_integration_20260507_102205.log`
- B3 integration: PASS - `progress/sprint_24/test_run_B3_integration_20260507_102214.log`

Live/OCI:

- LIVE-24-01..04: NOT RUN (pending OCI execution)

