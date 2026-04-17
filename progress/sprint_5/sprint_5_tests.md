# Sprint 5 — Tests

## Status: tested

## Executed Validation

- reuse Sprint 4 validation shape and artifact checks where still applicable
- verify `progress/sprint_5/oracle-layout.fio` matches the corrective workload profile exactly
- verify fio JSON contains distinct job entries for:
  - `data-8k`
  - `redo`
  - `fra-1m`
- verify `iostat` confirms traffic isolation across:
  - data stripe
  - redo stripe
  - FRA volume
- verify compute and all five block volumes are torn down automatically after the run

## Executed Runs

- `FIO_RUNTIME_SEC=60 RUN_LEVEL=smoke OCI_REGION=eu-zurich-1 ./tools/run_bv_fio_oracle_sprint5.sh`
- `FIO_RUNTIME_SEC=600 RUN_LEVEL=integration OCI_REGION=eu-zurich-1 ./tools/run_bv_fio_oracle_sprint5.sh`

## Result

- Smoke run completed successfully.
- Integration run completed successfully.
- Corrected fio reporting is preserved with `group_reporting=0`.
- fio JSON contains per-job records for:
  - `data-8k`
  - `redo`
  - `fra-1m`
- Compute instance and all five block volumes were torn down automatically after the integration run.

## Artifacts

- `progress/sprint_5/fio-results-oracle-smoke.json`
- `progress/sprint_5/iostat-oracle-smoke.json`
- `progress/sprint_5/fio-analysis-oracle-smoke.md`
- `progress/sprint_5/fio-results-oracle-integration.json`
- `progress/sprint_5/iostat-oracle-integration.json`
- `progress/sprint_5/fio-analysis-oracle-integration.md`
- `progress/sprint_5/state-bv4db-oracle5-run.deleted-20260417T200905.json`

## Success Condition

Sprint 5 passes only if the fio result is valid at workload level, not only at aggregate level.
