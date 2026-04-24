# Correlation Report Generation Manual (Operator)

This document explains how to generate the **Sprint correlation reports** (Markdown + HTML) from archived sprint source data.

## What the tool generates

For each sprint \(N\), it generates:

- `progress/sprint_19/sprint_N_correlation_report.md`
- `progress/sprint_19/sprint_N_correlation_report.html`
- `progress/sprint_19/analysis_results.json` (summary across runs)

The report covers two phases (when artifacts exist):

- **FIO phase** (storage benchmark)
- **Swingbench phase** (database workload)

## Prerequisites

- Python 3 available as `python3`
- Install Python dependencies:

```bash
python3 -m pip install -r tools/analysis/requirements.txt
```

## Source data location and naming

Place sprint artifacts under:

- `progress/sprint_<N>/`

The analysis CLI auto-discovers inputs by filename patterns. The most common expected filenames are:

### FIO phase

- `fio_results.json`
- `fio_iostat.json`
- `fio_oci_metrics_raw.json`

### Swingbench phase

- `swingbench_results_db.json`
- `swingbench_iostat.json`
- `swingbench_oci_metrics_raw.json`

If some files are missing, the phase may be marked **INCONCLUSIVE** or **FAIL** depending on what evidence is available.

## Run report generation

### Generate one sprint report

```bash
python3 tools/analysis/analyze_sprint.py --sprint 18 --base-dir progress --output-dir progress/sprint_19
```

### Generate multiple sprints (space-separated)

```bash
python3 tools/analysis/analyze_sprint.py --sprint 17 18 --base-dir progress --output-dir progress/sprint_19
```

### Generate all sprints found under `progress/`

```bash
python3 tools/analysis/analyze_sprint.py --all --base-dir progress --output-dir progress/sprint_19
```

### Also write/update the JSON summary file

```bash
python3 tools/analysis/analyze_sprint.py --sprint 18 --base-dir progress --output-dir progress/sprint_19 --json progress/sprint_19/analysis_results.json
```

## How to interpret key report signals

### Topology-aware variables (what to look at)

The “Full Correlation Matrix” intentionally focuses on **topology-level** variables:

- `io_*_mbps` / `iostat_*_mbps` (guest iostat, aggregated to `boot/data/redo/fra`)
- `oci_*_mbps` (OCI Monitoring throughput, aggregated to `boot/data/redo/fra`)
- `tps` (Swingbench TPS time series, when available)
- `fio_*_mbps` (FIO workload throughput; see note below)

Raw drill-down columns like `data1_*`, `data2_*`, `redo1_*`, `redo2_*`, and host-wide aggregates like `read_kbps` are excluded from the default matrix on purpose.

### Low sample size warning

Short runs (especially Sprint 17 Swingbench) can have very few overlapping time points. The correlation matrix will show a warning like:

- **“min n = X … values based on n < 10 are not statistically meaningful”**

Treat any “perfect” correlation \(e.g. \(r=1.00\)\) as **meaningless** when `n` is small.

### Synthetic FIO time series (current-stage behavior)

In this repository, `fio_results.json` is summary-style. If real per-interval fio logs are not present, the tool synthesizes `fio_*_mbps` as a time series using:

- the fio summary throughput level (base), and
- the measured topology throughput series as a “shape proxy” (best-effort),

so that `fio_*_mbps` can participate in time-series correlation plots/matrices.

This is a **workaround** until real fio time-series logs are added.

### Sprint failure conditions (example: Swingbench on boot volume)

The analysis can mark a Swingbench phase **FAIL** when the run is structurally invalid, e.g.:

- boot volume dominates I/O (`R6: swingbench_boot_dominant_io`)

This typically indicates the database files were placed on the boot volume rather than `/u02` (data), `/u03` (redo), `/u04` (fra).

## Troubleshooting

### “ModuleNotFoundError: No module named 'loaders'”

Run the CLI from the repo root:

```bash
python3 tools/analysis/analyze_sprint.py --sprint 18 --base-dir progress --output-dir progress/sprint_19
```

### Report generated but missing `tps`

Check that `progress/sprint_<N>/swingbench_results_db.json` contains TPS readings and timestamps.

### OCI metrics look “flat” or zero

OCI Monitoring is 1-minute aggregated. For reliable correlation, use longer runs (e.g. 900s mirror runs).

