# Sprint 12 Implementation

Status: tested

YOLO decision log:

- Ambiguity: whether to use an external charting library for the HTML report.
  Assumption: generate a self-contained HTML file with inline CSS and SVG charts.
  Rationale: this keeps the report portable and avoids adding runtime or packaging complexity to `oci_scaffold`.
  Risk: low.

- Ambiguity: whether the metrics validation run should stay single-volume like Sprint 11 or move to a richer topology.
  Assumption: use a short Balanced multi-volume Oracle run.
  Rationale: the user asked for a compute run with more than one block volume, and block volume charts are more useful when the report covers several storage resources.
  Risk: low.

Execution summary:

- extend `operate-metrics.sh` to emit Markdown, raw JSON, and HTML report artifacts from the same collected metrics
- carry formatting metadata into the raw JSON payload so HTML and Markdown present values consistently
- execute a `300`-second Balanced multi-volume Oracle-style load
- synthesize a metrics collection state containing compute, multiple block volumes, and primary VNIC
- collect OCI Monitoring metrics through `operate-*` scripts and generate both report formats

Artifacts produced:

- `progress/sprint_12/fio-results-oracle-balanced-multi-metrics-300s.json`
- `progress/sprint_12/iostat-oracle-balanced-multi-metrics-300s.json`
- `progress/sprint_12/fio-analysis-oracle-balanced-multi-metrics-300s.md`
- `progress/sprint_12/oci-metrics-report.md`
- `progress/sprint_12/oci-metrics-report.html`
- `progress/sprint_12/oci-metrics-raw.json`
- `progress/sprint_12/state-metrics-oracle12.json`

Observed result:

- metrics were collected for `7` resources:
  - `1` compute instance
  - `5` block volumes
  - `1` primary VNIC
- the raw metrics artifact contains `28` metric series
- the HTML dashboard renders chart cards for compute, block volume, and network metrics from the same collected payload used by the Markdown report
