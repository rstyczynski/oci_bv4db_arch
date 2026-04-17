# Sprint 3 — Implementation

## Status: tested

## Planned Implementation

- `progress/sprint_3/mixed-8k.fio` stores the required fio workload file
- `tools/run_bv_fio_mixed8k.sh` reuses the Sprint 2 UHP topology setup path and runs fio from the profile file
- `tests/integration/test_bv4db_mixed8k.sh` validates the Sprint 3 smoke artifacts

## Key Design Choices

- Runtime levels: smoke `60s`, integration `900s`
- fio workload source: profile file, not inline CLI arguments
- topology: same as Sprint 2 UHP benchmark

## Current Result

- Smoke run completed successfully in `eu-zurich-1`
- Raw artifact: `progress/sprint_3/fio-results-mixed8k-smoke.json`
- Analysis artifact: `progress/sprint_3/fio-analysis-mixed8k-smoke.md`
- Archived state: `progress/sprint_3/state-bv4db-mixed8k-run.deleted-20260417T155357.json`
- Verification: `tests/integration/test_bv4db_mixed8k.sh` passed `4/4`
- Remaining work: execute the `15`-minute integration run on the same profile
