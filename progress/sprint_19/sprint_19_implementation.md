# Sprint 19 Implementation - BV4DB-48

## Overview

Sprint 19 implements a data science correlation framework to validate benchmark evidence across observation layers (Guest I/O, OCI Block Volume metrics, Swingbench TPS).

## Deliverables

### Analysis Framework (`tools/analysis/`)

```
tools/analysis/
├── __init__.py
├── analyze_sprint.py           # CLI entry point
├── loaders/
│   ├── __init__.py
│   ├── fio_loader.py           # FIO JSON parser
│   ├── iostat_loader.py        # sysstat JSON parser
│   ├── oci_metrics_loader.py   # OCI metrics JSON parser
│   └── swingbench_loader.py    # Swingbench XML/JSON parser
├── correlation/
│   ├── __init__.py
│   ├── time_alignment.py       # Time-series alignment
│   ├── correlation_engine.py   # Pearson/Spearman/Quadrant
│   └── anomaly_detector.py     # Rules R1-R5
└── reporting/
    ├── __init__.py
    ├── quality_scorer.py       # Evidence quality scoring
    └── report_generator.py     # MD/HTML report generation
```

### Generated Reports (`progress/sprint_19/`)

| File | Description |
|------|-------------|
| `analysis_results.json` | Machine-readable analysis output |
| `correlation_fio_s17.md/.html` | Sprint 17 FIO correlation report |
| `correlation_fio_s18.md/.html` | Sprint 18 FIO correlation report |
| `correlation_swingbench_s17.md/.html` | Sprint 17 Swingbench correlation report |
| `correlation_swingbench_s18.md/.html` | Sprint 18 Swingbench correlation report |

## Analysis Results Summary

### Sprint 17

| Phase | Score | Grade | Verdict | Key Finding |
|-------|-------|-------|---------|-------------|
| FIO | 65/100 | C | INCONCLUSIVE | Low correlation (r=0.13), only 9 aligned samples |
| Swingbench | 10/100 | F | INCONCLUSIVE | Critical: OCI shows 0 MB/s while iostat shows 114 MB/s |

**Sprint 17 Issues:**
- Short test duration (60s for FIO, ~1min for Swingbench)
- OCI metrics may have wrong OCID or timing mismatch
- Only 4 aligned samples for Swingbench phase

### Sprint 18

| Phase | Score | Grade | Verdict | Key Finding |
|-------|-------|-------|---------|-------------|
| FIO | 100/100 | A | PASS | Excellent correlation (r=0.926), 18 aligned samples |
| Swingbench | 75/100 | B | PASS | Low correlation (r=0.10) but no critical anomalies |

**Sprint 18 Improvements:**
- Extended test duration (900s = 15 minutes)
- More samples available for correlation analysis
- FIO phase demonstrates correct cross-layer behavior

## Correlation Methods Applied

### 1. Pearson Correlation
Linear correlation between guest I/O (iostat) and OCI Block Volume throughput.
- Sprint 18 FIO: r = 0.926 (p < 0.001) - Strong linear relationship
- Sprint 18 Swingbench: r = 0.10 (p = 0.56) - Weak, not significant

### 2. Spearman Rank Correlation
Non-parametric correlation for monotonic relationships.
- Sprint 18 FIO: ρ = 0.36 (p = 0.14) - Moderate monotonic trend
- Sprint 18 Swingbench: ρ = 0.27 (p = 0.11) - Weak monotonic trend

### 3. Quadrant Correlation Matrix
Categorical agreement between above/below median values.
- Sprint 18 FIO: 44% agreement (chi² = 5.0, p = 0.29)
- Sprint 18 Swingbench: 43% agreement (chi² = 2.1, p = 0.72)

### 4. Resource-mapped correlations (topology-aware)

Correlation variables are derived at the **resource** level to avoid mixing unrelated devices/volumes and to make placement defects obvious.

Per phase, per resource (examples):
- iostat: `iostat_boot_mbps`, `iostat_data_mbps`, `iostat_redo_mbps`, `iostat_fra_mbps`
- OCI: `oci_boot_mbps`, `oci_data1_mbps`, `oci_data2_mbps`, `oci_redo1_mbps`, `oci_redo2_mbps`, `oci_fra_mbps`
- FIO (FIO phase only): `fio_data_mbps`, `fio_redo_mbps`, `fio_fra_mbps`
- Swingbench (Swingbench phase only): `swing_tps_total` (optional `swing_tps_<tx_name>`)

Group aggregations:
- `oci_data_mbps = oci_data1_mbps + oci_data2_mbps`
- `oci_redo_mbps = oci_redo1_mbps + oci_redo2_mbps`

Reports include per-resource correlation tables and “best match” summaries (e.g., redo correlates, boot unexpectedly hot).

### 5. Lagged correlation (iostat ↔ OCI)

OCI Monitoring is 1-minute aggregated and can be time-shifted. For matched resource pairs:
- evaluate lag \(\pm\) 0..5 minutes (configurable)
- report best lag + Pearson/Spearman coefficients (with p-values) and aligned N

## Anomaly Detection Rules

| Rule | Description | Sprint 17 | Sprint 18 |
|------|-------------|-----------|-----------|
| R1 | Guest vs OCI throughput mismatch (>10x) | Swingbench: FAIL | OK |
| R2 | FIO vs reported BW mismatch (>20%) | OK | OK |
| R3 | Swingbench TPS vs Block I/O mismatch | Swingbench: FAIL | OK |
| R4 | IOPS exceeds theoretical max | OK | OK |
| R5 | Cross-layer correlation < 0.5 | Both: WARN | Swingbench: WARN |

## Evidence Quality Scoring

The quality score (0-100) is computed from four components:

1. **Cross-layer Correlation (25 pts)**
   - 25 pts: r ≥ 0.7
   - 15 pts: r ≥ 0.5
   - 0 pts: r < 0.5

2. **Anomaly Check (25 pts)**
   - 25 pts: No critical anomalies
   - 0 pts: Any critical anomaly (R1-R4)

3. **Topology Match (25 pts)**
   - 25 pts: Storage mapping verified
   - 0 pts: Mapping inconsistent

4. **Time Coverage (25 pts)**
   - 25 pts: Coverage ≥ 80%
   - Proportional reduction for lower coverage

### Time coverage calculation (derived)

Time coverage is computed from the actual phase window and sampling frequency:
- expected_points = number of 1-minute buckets in \([start, end]\)
- actual_points = number of buckets with non-null OCI values for matched resource(s)
- coverage = actual_points / expected_points

## Usage

```bash
# Analyze specific sprints
python3 tools/analysis/analyze_sprint.py --sprint 17 18 \
    --base-dir progress \
    --output-dir progress/sprint_19 \
    --json progress/sprint_19/analysis_results.json

# View HTML reports
open progress/sprint_19/correlation_fio_s18.html
```

## Recommendations

1. **Sprint 17 Re-validation**: The OCI metrics collection appears to have failed during Swingbench phase. Consider re-running with verified OCIDs.

2. **Extended Test Duration**: Sprint 18's 15-minute tests produced better correlation than Sprint 17's 1-minute tests.

3. **Swingbench Correlation**: Even with good data (Sprint 18), Swingbench I/O patterns show weak correlation with block volume metrics. This may be expected due to database caching, WAL buffering, and checkpoint behavior.

4. **Adopt per-resource correlation as primary diagnostic**: Evaluate boot/data/redo/fra separately; a “boot hot / data idle” signature is a strong placement indicator even if aggregate correlations appear acceptable.

## Test Evidence

- Sprint 17 data: `progress/sprint_17/`
- Sprint 18 data: `progress/sprint_18/`
- Analysis framework: `tools/analysis/`
- Generated reports: `progress/sprint_19/`

## Status

**Phase: Transition**
**Sprint 19: COMPLETE**
