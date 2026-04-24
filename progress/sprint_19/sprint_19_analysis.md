# Sprint 19 - Analysis

Status: Complete

## Sprint Overview

Sprint 19 implements BV4DB-48: Analyze benchmark and test outcomes for evidence quality, contradictions, and conclusions. This is a data science analysis sprint using Pandas and statistical correlation techniques.

## Backlog Items Analysis

### BV4DB-48: Analyze benchmark and test outcomes

**Requirement Summary:**

Examine completed sprint outputs and validate whether resulting conclusions are defensible, sufficiently correlated, and evidence-complete. Define analytical rules for future sprints: what evidence is mandatory, what contradictions are disqualifying, how benchmark-quality correlation is recognized.

**Technical Approach:**

Apply data science methodology using:

- **Pandas DataFrames**: Unified data model for all observation layers
- **Time-series alignment**: Correlate metrics across FIO, iostat, OCI Monitoring, Swingbench TPS
- **Statistical correlation**: Pearson/Spearman coefficients between observation layers
- **Anomaly detection**: Identify contradictions (e.g., zero OCI metrics during active iostat)
- **Visualization**: Matplotlib/Seaborn for correlation heatmaps and time-series plots

**Dependencies:**

- Completed Sprint 15, 17, 18 artifacts
- Historical baselines from Sprints 1-12
- Python 3.x with Pandas, NumPy, Matplotlib, Seaborn

**Testing Strategy:**

- Integration test: Python analysis scripts execute successfully
- Validation: Correlation analysis produces documented findings
- Acceptance: Evidence quality rules defined and applied to prior sprints

**Risks/Concerns:**

- Sprint 16 already noted correlation failure (Swingbench not hitting block volumes)
- Sprint 18 may have same issue (BV4DB-47 not yet implemented)
- Analysis may reveal other sprints require failure marking

**Compatibility Notes:**

Integrates with existing repository structure. Analysis outputs will be Python scripts in `tools/analysis/` and results in `progress/sprint_19/`.

## Data Inventory

### Layer 1: FIO Benchmark Results (Storage-Level)

| Sprint | File | Topology | Duration | Key Metrics |
|--------|------|----------|----------|-------------|
| 1 | fio-results.json | single BV | smoke | IOPS, BW, latency |
| 2 | fio-results-perf*.json | max-perf BV | smoke | IOPS, BW, latency |
| 3 | fio-results-mixed8k-smoke.json | max-perf BV | smoke | mixed 8k |
| 4 | fio-results-oracle-*.json | multi-BV Oracle | smoke/int | data/redo/fra |
| 5 | fio-results-oracle-*.json | multi-BV Oracle | smoke/int | corrected |
| 8 | fio-results-oracle-integration.json | single UHP | int | Oracle jobs |
| 9 | fio-results-oracle-*-4k-redo-*.json | single/multi | int | 4k redo |
| 10 | fio-results-oracle-*-4k-redo-*.json | perf tiers | int | tier comparison |
| 11 | fio-results-oracle-balanced-single-metrics-300s.json | balanced | 300s | with OCI metrics |
| 12 | fio-results-oracle-balanced-multi-metrics-300s.json | balanced multi | 300s | with OCI metrics |
| 17 | fio_results.json | UHP multi | 60s | consolidated |
| 18 | fio_results.json | UHP multi | 900s | benchmark-quality |

**FIO Data Structure:**
- Per-job: read/write IOPS, bandwidth, latency (mean, percentiles)
- Disk utilization: per-device read_ios, write_ios, ticks
- Timestamps for correlation

### Layer 2: Guest iostat (OS-Level)

| Sprint | File | Observation Window |
|--------|------|--------------------|
| 4 | iostat-oracle-smoke.json | smoke |
| 4 | iostat-oracle-integration.json | integration |
| 5 | iostat-oracle-smoke.json, iostat-oracle-integration.json | smoke/int |
| 8 | iostat-oracle-integration.json | integration |
| 9 | iostat-oracle-single-4k-redo-integration.json | single |
| 9 | iostat-oracle-multi-4k-redo-integration.json | multi |
| 10 | iostat-oracle-*-4k-redo-integration.json | all tiers |
| 11 | iostat-oracle-balanced-single-metrics-300s.json | 300s |
| 12 | iostat-oracle-balanced-multi-metrics-300s.json | 300s |
| 17 | fio_iostat.json, swingbench_iostat.json | both phases |
| 18 | fio_iostat.json, swingbench_iostat.json | both phases |

**iostat Data Structure:**
- Per-device: r/s, w/s, rkB/s, wkB/s, %util
- Time-series samples
- Device mapping to LVM/BV

### Layer 3: OCI Monitoring Metrics (Provider-Level)

| Sprint | File | Resources Covered |
|--------|------|-------------------|
| 11 | oci-metrics-raw.json | compute, single BV |
| 12 | oci-metrics-raw.json | compute, multi BV |
| 17 | fio_oci_metrics_raw.json | FIO phase: data1, data2, redo1, redo2, fra |
| 17 | swingbench_oci_metrics_raw.json | Swingbench phase |
| 18 | fio_oci_metrics_raw.json | FIO phase (900s) |
| 18 | swingbench_oci_metrics_raw.json | Swingbench phase (900s) |

**OCI Metrics Data Structure:**
- VolumeReadThroughput, VolumeWriteThroughput (bytes/interval)
- VolumeReadOps, VolumeWriteOps (count)
- 1-minute resolution timestamps
- Per-volume granularity

### Layer 4: Swingbench Database Workload

| Sprint | Files | Duration | TPS |
|--------|-------|----------|-----|
| 15 | swingbench_results_db.json, swingbench_results.xml | 5 min | ~1500 |
| 17 | swingbench_results_db.json, swingbench_results.xml | 1 min | ~2116 |
| 18 | swingbench_results_db.json, swingbench_results.xml | 15 min | ~1466 |

**Swingbench Data Structure:**
- Per-transaction: count, avg/min/max response, percentiles
- TPSReadings: timestamp, TPS time-series
- DML counts: select, insert, update, delete, commit

### Layer 5: AWR Database Diagnostics

| Sprint | AWR Snapshots | Key Wait Events |
|--------|---------------|-----------------|
| 14 | 1 → 2 | Initial capture |
| 15 | 1 → 2 | log file sync, db file sequential read |
| 17 | 1 → 2 | log file sync ~646us |
| 18 | 1 → 2 | 15-min window |

**AWR Data Points:**
- DB CPU time and percentage
- log file sync: waits, time, avg wait
- db file sequential read: waits, time, avg wait
- Physical read/write bytes
- Redo size

## Test Windows and Time Frames

### Sprint 17 Time Windows

| Phase | Start (UTC) | End (UTC) | Duration | Prep Time |
|-------|-------------|-----------|----------|-----------|
| FIO | 2026-04-23T16:05:39Z | 2026-04-23T16:14:55Z | ~9 min | ~5 min setup |
| Swingbench | 2026-04-23T16:21:47Z | 2026-04-23T16:25:46Z | ~4 min | ~7 min DB prep |
| AWR Window | snap 1 → snap 2 | - | Swingbench duration | - |

### Sprint 18 Time Windows

| Phase | Start (UTC) | End (UTC) | Duration | Prep Time |
|-------|-------------|-----------|----------|-----------|
| FIO | 2026-04-23T20:22:58Z | 2026-04-23T20:40:28Z | ~17 min | ~5 min setup |
| Swingbench | 2026-04-23T21:43:45Z | 2026-04-23T22:18:01Z | ~34 min | ~63 min DB prep |
| AWR Window | snap 1 → snap 2 | - | 15 min benchmark | - |

### OCI Metrics Resolution

- OCI Monitoring resolution: 1 minute
- Minimum useful benchmark window: 5+ minutes for meaningful OCI correlation
- Sprint 17 Swingbench (~1 min actual): Too short for OCI block volume correlation
- Sprint 18 Swingbench (15 min actual): Sufficient for OCI correlation analysis

## Known Correlation Issues

### Sprint 16 Failure (Documented)

Sprint 16 correlation analysis was marked failed because:
- Guest iostat during Swingbench did not sustain expected data-volume traffic
- OCI block-volume metrics were nearly all zero during Swingbench
- Boot device showed strong activity instead
- Root cause: Database files placed on boot volume, not project block volumes

### Sprint 18 Suspected Issue

Preliminary observation from OCI metrics:
- FIO phase: Strong block volume activity (data1 ~2.5 GiB/s read)
- Swingbench phase: Near-zero block volume read (0.0 after initial)
- This matches Sprint 16/17 pattern suggesting BV4DB-47 not resolved

## Correlation Techniques to Apply

### 1. Time-Series Alignment

```python
# Align all observation layers to common time index
fio_df = pd.DataFrame(fio_results)
iostat_df = pd.DataFrame(iostat_samples)
oci_df = pd.DataFrame(oci_metrics)

# Resample to 1-minute buckets for correlation
aligned = pd.merge_asof(fio_df, iostat_df, on='timestamp')
```

### 2. Cross-Layer Correlation Matrix

```python
# Pearson correlation between:
# - FIO bandwidth vs iostat throughput
# - iostat throughput vs OCI VolumeWriteThroughput
# - Swingbench TPS vs OCI metrics
correlation_matrix = df[metrics].corr(method='pearson')

# Spearman for non-linear relationships
spearman_matrix = df[metrics].corr(method='spearman')
```

#### Variable selection (topology-aware)

To avoid misleading results caused by mixing unrelated devices/volumes, correlation is computed on **resource-mapped variables** instead of generic host aggregates.

Examples (names are illustrative; actual columns are derived from topology mapping):
- iostat: `iostat_boot_mbps`, `iostat_data_mbps`, `iostat_redo_mbps`, `iostat_fra_mbps`
- OCI BV: `oci_boot_mbps`, `oci_data1_mbps`, `oci_data2_mbps`, `oci_redo1_mbps`, `oci_redo2_mbps`, `oci_fra_mbps`
- FIO (FIO phase only): `fio_data_mbps`, `fio_redo_mbps`, `fio_fra_mbps`
- Swingbench (Swingbench phase only): `swing_tps_total` (optional `swing_tps_<tx_name>`)

Correlation is reported:
- **Per phase**: FIO and Swingbench are analyzed separately.
- **Per resource**: boot/data/redo/fra correlations are computed against their matching OCI volumes.

#### Lagged correlation (iostat ↔ OCI)

OCI metrics are 1-minute aggregated and may be time-shifted relative to iostat. For each matched resource pair, compute correlation at lag \(\pm\) 0..5 minutes and report:
- best lag (minutes)
- Pearson r and p-value at best lag
- Spearman ρ and p-value at best lag
- aligned sample count (N)

### 3. Quadrant Correlation Matrix

Bin continuous metrics into categories (Low/Medium/High) and visualize cross-layer agreement:

```python
# Categorize throughput levels
def categorize_throughput(value, thresholds):
    if value < thresholds[0]:
        return 'Low'
    elif value < thresholds[1]:
        return 'Medium'
    else:
        return 'High'

# Create contingency table
quadrant_matrix = pd.crosstab(
    df['iostat_category'],
    df['oci_category'],
    margins=True
)

# Chi-squared test for independence
chi2, p_value, dof, expected = scipy.stats.chi2_contingency(quadrant_matrix)
```

This reveals whether observation layers agree on activity levels even when absolute values differ.

### 4. Anomaly Detection Rules

| Rule | Condition | Action |
|------|-----------|--------|
| R1 | iostat shows activity AND OCI metrics near-zero | Flag contradiction |
| R2 | FIO target device != iostat active devices | Flag topology mismatch |
| R3 | Swingbench TPS stable AND block volume metrics zero | Flag placement defect |
| R4 | AWR redo size > 0 AND redo volume OCI metrics zero | Flag redo placement |

### 4. Evidence Quality Scoring

```python
def evidence_quality_score(sprint_data):
    score = 0

    # Cross-layer correlation >= 0.7
    if cross_layer_correlation >= 0.7:
        score += 25

    # No anomaly flags
    if anomaly_count == 0:
        score += 25

    # All expected devices show activity
    if topology_match:
        score += 25

    # Time coverage >= 80% of window
    if time_coverage >= 0.8:
        score += 25

    return score  # 0-100
```

#### Time coverage calculation (derived, not constant)

Time coverage is computed from actual phase start/end timestamps and sampling frequency:
- expected_points = number of `freq` buckets in \([start, end]\)
- actual_points = number of buckets with non-null OCI data for the matched resource(s)
- coverage = actual_points / expected_points

## Overall Sprint Assessment

**Feasibility:** High
- All data sources exist and are accessible
- Python/Pandas environment standard for data science
- Clear methodology defined

**Estimated Complexity:** Moderate
- Multiple data formats to parse
- Time-series alignment required
- Correlation logic to implement

**Prerequisites Met:** Yes
- Completed sprints 15, 17, 18 with artifacts
- Historical baselines available
- Sprint 16 correlation doc provides failure case study

**Open Questions:** None

## Recommended Design Focus Areas

1. **Data Loading Pipeline**: Unified JSON parsers for all data types
2. **Time-Series Normalization**: Handle different sampling rates
3. **Correlation Engine**: Configurable correlation rules
4. **Anomaly Detector**: Rule-based contradiction finder
5. **Report Generator**: Markdown/HTML output with visualizations

## Readiness for Design Phase

**Confirmed Ready**
