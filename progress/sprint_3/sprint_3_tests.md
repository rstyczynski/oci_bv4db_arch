# Sprint 3 - Tests

## Planned Test Configuration

- **Mode:** managed
- **Test:** integration
- **Regression:** integration
- **Region:** `eu-zurich-1`
- **Shared infra source:** `progress/sprint_1/state-bv4db.json`
- **Topology source:** Sprint 2 UHP compute and block volume configuration

## Planned Checks

### IT-10: Mixed 8k fio profile file present

Verify the fio workload file exists and contains the expected mixed `8k` profile.

### IT-11: Smoke run completed on Sprint 2 topology

Verify the `60`-second smoke run completes and writes a valid fio JSON artifact.

### IT-12: Smoke analysis written

Verify the Sprint 3 smoke analysis file exists and summarizes the mixed `8k` results.

### IT-13: Smoke resources torn down automatically

Verify the Sprint 3 smoke run deletes the benchmark compute and block volume and archives the state file.

## Current Execution Status

- Sprint 3 closed with the smoke execution level completed and verified
- The `15`-minute integration execution level remains available as future follow-on work on the same profile
