# Sprint 19 Manual — Correlation Analysis (Operator)

Sprint 19 is an **analysis sprint**. Its output is a consistent, topology-aware correlation report for **Sprint 17 and Sprint 18** evidence.

## What this sprint produces

Generated under `progress/sprint_19/`:

- `sprint_17_correlation_report.md` + `.html`
- `sprint_18_correlation_report.md` + `.html`
- `analysis_results.json` (summary)

## Prerequisites

- Run commands from repository root
- Python dependencies:

```bash
python3 -m pip install -r tools/analysis/requirements.txt
```

## Required source artifacts

Sprint directories must exist:

- `progress/sprint_17/`
- `progress/sprint_18/`

Each sprint should include (as available):

### FIO phase

- `fio_results.json`
- `fio_iostat.json`
- `fio_oci_metrics_raw.json`

### Swingbench phase

- `swingbench_results_db.json`
- `swingbench_iostat.json`
- `swingbench_oci_metrics_raw.json`

## Generate reports

Run Sprint 17:

```bash
python3 tools/analysis/analyze_sprint.py --sprint 17 --base-dir progress --output-dir progress/sprint_19 --json progress/sprint_19/analysis_results.json
```

Run Sprint 18:

```bash
python3 tools/analysis/analyze_sprint.py --sprint 18 --base-dir progress --output-dir progress/sprint_19 --json progress/sprint_19/analysis_results.json
```

Run both:

```bash
python3 tools/analysis/analyze_sprint.py --sprint 17 18 --base-dir progress --output-dir progress/sprint_19 --json progress/sprint_19/analysis_results.json
```

## How to review outputs (Sprint 19 acceptance)

Open the HTML reports first:

- `progress/sprint_19/sprint_17_correlation_report.html`
- `progress/sprint_19/sprint_18_correlation_report.html`

Verify:

- **Topology-aware variables** appear in the full matrix:
  - `io_*_mbps` (guest iostat, aggregated to `boot/data/redo/fra`)
  - `oci_*_mbps` (OCI Monitoring throughput, aggregated to `boot/data/redo/fra`)
  - `tps` (Swingbench time series)
  - `fio_*_mbps` (FIO workload; may be synthetic when only summary artifacts exist)
- **Low sample-size guardrails**:
  - the matrix contains a warning when overlap is small (min `n`)
  - “Significant correlations” include `n` and exclude tiny overlaps
- **Sprint 17 Swingbench caveat**:
  - treat Swingbench evidence as invalid if I/O is boot-dominant (wrong DB placement)

## Notes

- OCI Monitoring is **1-minute aggregated**. Short runs can produce misleading correlations; always consider overlap `n`.
- Current fio artifacts are summary-style; until per-interval fio logs are added, `fio_*_mbps` may be generated as a synthetic time series for correlation completeness.
