# Sprint 17 Implementation

## YOLO decisions

1. build Sprint 17 as one dedicated orchestrator instead of chaining earlier sprint wrappers that assume different topologies and teardown timing
2. keep the established Oracle-style multi-volume split for storage-domain observability and use a higher-end compute profile so the summary sprint stays aligned with earlier Oracle fio evidence
3. reuse the Sprint 15 Swingbench benchmark definition and HTML renderer, extending that path with guest `iostat` and OCI metrics collection
4. add a dedicated FIO HTML renderer rather than forcing operators to infer the storage phase only from raw JSON and Markdown analysis

## Implementation summary

Sprint 17 adds a single combined benchmark flow that:

1. provisions a multi-volume Oracle-style topology on a UHP-sized compute profile
2. runs the Oracle-style `fio` phase with guest `iostat`
3. collects OCI metrics and renders Markdown/HTML reports for the FIO window
4. installs Oracle Database Free on the same topology
5. runs the standardized `Swingbench` phase with guest `iostat`
6. captures AWR begin/end snapshots and exports the AWR HTML report
7. collects OCI metrics and renders Markdown/HTML reports for the Swingbench window
8. emits a consolidated summary artifact for the whole sprint

## Live validation notes

- the live Sprint 17 execution completed on `2026-04-23` without manual intervention after the hardened remote-step and teardown path fixes
- OCI capacity fallback was exercised in production: the requested `40 OCPU` profile fell back automatically to `20 OCPUs / 64 GB`
- the generated artifact set now includes:
  - `fio_report.html`
  - `fio_oci_metrics_report.html`
  - `swingbench_report.html`
  - `swingbench_oci_metrics_report.html`
  - `awr_report.html`
  - `sprint_17_summary.md`

## Files introduced

- `tools/run_oracle_db_sprint17.sh`
- `tools/render_fio_report_html.sh`
- `tests/integration/test_oracle_db_sprint17.sh`

## Reused assets

- Oracle-style multi-volume fio profile from Sprint 10
- OCI metrics collection and HTML reporting path from Sprint 11 and Sprint 12
- Oracle Database Free install and layout automation from Sprint 13
- AWR capture and export path from Sprint 14
- Swingbench runner, config handling, and HTML reporting from Sprint 15
