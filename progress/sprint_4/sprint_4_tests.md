# Sprint 4 — Tests

## Status: failed

## Executed Tests

- `OCI_REGION=eu-zurich-1 RUN_LEVEL=smoke FIO_RUNTIME_SEC=60 ./tools/run_bv_fio_oracle.sh`
- `OCI_REGION=eu-zurich-1 RUN_LEVEL=integration FIO_RUNTIME_SEC=900 ./tools/run_bv_fio_oracle.sh`

## Result

- Smoke run completed successfully.
- Integration run completed successfully.
- Compute instance was terminated automatically after each run.
- All five block volumes were detached and deleted automatically after each run.
- Local smoke artifacts:
  - `progress/sprint_4/fio-results-oracle-smoke.json`
  - `progress/sprint_4/iostat-oracle-smoke.json`
  - `progress/sprint_4/fio-analysis-oracle-smoke.md`
- Local integration artifacts:
  - `progress/sprint_4/fio-results-oracle-integration.json`
  - `progress/sprint_4/iostat-oracle-integration.json`
  - `progress/sprint_4/fio-analysis-oracle-integration.md`

## Failure Reason

- Sprint 4 is failed.
- Root cause: `group_reporting=1` in `progress/sprint_4/oracle-layout.fio`
- Effect: fio collapsed the concurrent jobs into a single aggregated reporting group.
- Consequence: the produced fio JSON does not provide valid per-workload results for `data-8k`, `redo`, and `fra-1m`.
- Outcome: Sprint 4 artifacts are not valid for the intended workload-level validation, even though the storage layout, execution, and teardown completed.

## Observations

- `fio` reports the concurrent workload as a single aggregated JSON group because `group_reporting=1` was enabled.
- Device-level `iostat` still shows the intended layout behavior:
  - data stripe carries the dominant mixed random load
  - redo traffic stays on the redo stripe
  - FRA traffic remains isolated on the FRA volume
- Integration run summary:
  - aggregated fio throughput about `433 MB/s` read and `255 MB/s` write
  - aggregated fio rate about `52.4k` read IOPS and `22.7k` write IOPS
  - data stripe average utilization about `69%`
  - redo stripe average utilization about `81%` on `dm-5`
  - FRA average utilization about `93%` on `sdn`

## Validation

- `./tests/integration/test_bv4db_oracle.sh`
- Result: passing only for infrastructure and artifact-presence checks, not for valid per-job fio reporting
- Integration artifact validation:
  - `progress/sprint_4/fio-results-oracle-integration.json` is valid JSON
  - `progress/sprint_4/iostat-oracle-integration.json` is valid JSON
  - archived deleted state files confirm teardown completion

## Required Fix

- remove `group_reporting=1` from `progress/sprint_4/oracle-layout.fio`
- rerun smoke and integration levels
- regenerate fio analysis from per-job results
