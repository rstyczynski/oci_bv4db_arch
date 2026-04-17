# Sprint 2 - Tests

## Planned Test Configuration

- **Mode:** managed
- **Test:** integration
- **Regression:** integration
- **Region:** `eu-zurich-1`
- **Shared infra source:** `progress/sprint_1/state-bv4db.json`

## Planned Integration Checks

### IT-5: Maximum-performance compute instance provisioned

Verify the Sprint 2 benchmark instance is created in the Sprint 1 shared subnet using the planned high-performance shape.

### IT-6: Ultra High Performance block volume attached

Verify the Sprint 2 block volume is created with the intended UHP configuration and attached successfully to the benchmark instance using the required high-performance path.

### IT-7: 60-second fio benchmark completed

Verify the benchmark run completes and writes a valid raw fio JSON result artifact for Sprint 2.

### IT-8: per-workload fio artifacts and analysis written

Verify the Sprint 2 sequential and random fio JSON files exist separately and the analysis file summarizes the measured results against the Sprint 1 baseline.

### IT-9: Benchmark resources torn down automatically

Verify the benchmark workflow deletes the benchmark compute instance and block volume after fio completion.

## Planned Teardown

Sprint 2 auto-tears down benchmark compute and block volume at benchmark completion.
