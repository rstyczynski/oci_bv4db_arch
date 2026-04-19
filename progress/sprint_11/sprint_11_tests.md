# Sprint 11 Tests

Status: tested

Test level:

- `integration`

Regression level:

- `integration`

Planned validation:

- execute a `5`-minute Oracle-style load run
- record the actual fio time window in run state
- synthesize a metrics collection state from the archived run state and archived volume state
- run `operate-metrics.sh` with the Sprint 11 metrics definition
- generate Markdown report and raw JSON metrics artifact
- verify compute, block volume, and network sections exist in the report

Executed validation:

- `5`-minute Balanced single-volume Oracle-style load completed and archived
- metrics state synthesized successfully from archived run state and archived block volume state
- `operate-metrics.sh` generated `oci-metrics-report.md`
- `operate-metrics.sh` generated `oci-metrics-raw.json`
- refactored operator still generated the expected report after resource logic moved into resource-owned `operate-*` scripts
- report contains compute, block volume, and network sections
- `tests/integration/test_oci_metrics_operate.sh` passed
