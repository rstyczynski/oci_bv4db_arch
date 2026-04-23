# Sprint 16 - Correlation Manual

Sprint 16 is a repository-only sprint. It does not provision OCI infrastructure when the source evidence already exists.

## What Sprint 16 uses

- Sprint 10 `fio` baselines
- Sprint 15 standardized `Swingbench` and AWR artifacts
- Sprint 17 consolidated `fio`, `Swingbench`, guest `iostat`, OCI metrics, and AWR artifacts

## Main outputs

- `sprint_16_correlation.md`
- `sprint_16_summary.md`

## Validation

```bash
bash tests/integration/test_oracle_db_sprint16.sh
```

## When to rerun infrastructure

Do not rerun OCI by default for Sprint 16.

Rerun only if the Sprint 15 or Sprint 17 source artifacts required by the integration test are missing. In that case, treat the missing source evidence as a Sprint 15 or Sprint 17 regression.
