# Sprint 12 Tests

Status: tested

Test level:

- `integration`

Regression level:

- `integration`

Planned validation:

- execute a `300`-second multi-volume Oracle-style run
- synthesize a metrics collection state containing compute, multiple volumes, and network resources
- run `operate-metrics.sh` with the Sprint 12 metrics definition
- generate Markdown, HTML, and raw JSON metrics artifacts
- verify the HTML report contains chart content for compute, block volume, and network metrics

Executed validation:

- `300`-second Balanced multi-volume Oracle-style run completed and archived
- metrics state synthesized successfully from the archived main run state plus archived `data1`, `data2`, `redo1`, `redo2`, and `fra` block volume states
- `operate-metrics.sh` generated:
  - `progress/sprint_12/oci-metrics-report.md`
  - `progress/sprint_12/oci-metrics-report.html`
  - `progress/sprint_12/oci-metrics-raw.json`
- the HTML report rendered chart cards for compute, block volume, and network metrics
- `tests/integration/test_oci_metrics_report_html.sh` passed
