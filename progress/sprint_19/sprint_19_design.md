# Sprint 19 - Design

## BV4DB-48: Analyze benchmark and test outcomes

Status: Approved

## Executive Summary

Sprint 19 introduces a **data science analysis framework** using Pandas to correlate benchmark observations across five measurement layers: FIO (storage), iostat (guest OS), OCI Monitoring (provider), Swingbench (database workload), and AWR (database diagnostics). The framework will:

1. Parse and normalize all JSON/XML data sources into Pandas DataFrames
2. Apply time-series alignment across observation layers
3. Calculate statistical correlations (Pearson, Spearman)
4. Detect anomalies and contradictions using rule-based logic
5. Score evidence quality and determine sprint pass/fail criteria
6. Generate correlation reports with visualizations

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

### OCI Metrics Resolution Constraints

- OCI Monitoring resolution: 1 minute
- Minimum useful benchmark window: 5+ minutes for meaningful OCI correlation
- Sprint 17 Swingbench (~1 min actual): Too short for OCI block volume correlation
- Sprint 18 Swingbench (15 min actual): Sufficient for OCI correlation analysis

## Data Science Architecture

### 1. Data Model

```
┌─────────────────────────────────────────────────────────────────────┐
│                     UNIFIED OBSERVATION MODEL                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐               │
│  │   FIO Layer  │  │ iostat Layer │  │  OCI Layer   │               │
│  │              │  │              │  │              │               │
│  │ - bandwidth  │  │ - r/s, w/s   │  │ - ReadTP     │               │
│  │ - iops       │  │ - rkB/s      │  │ - WriteTP    │               │
│  │ - latency    │  │ - wkB/s      │  │ - ReadOps    │               │
│  │ - disk_util  │  │ - %util      │  │ - WriteOps   │               │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘               │
│         │                 │                 │                        │
│         └────────────┬────┴─────────────────┘                        │
│                      │                                               │
│              ┌───────▼───────┐                                       │
│              │  Time-Aligned │                                       │
│              │   DataFrame   │                                       │
│              │               │                                       │
│              │ timestamp     │                                       │
│              │ fio_bw_read   │                                       │
│              │ fio_bw_write  │                                       │
│              │ iostat_rkBs   │                                       │
│              │ iostat_wkBs   │                                       │
│              │ oci_read_tp   │                                       │
│              │ oci_write_tp  │                                       │
│              └───────────────┘                                       │
│                                                                      │
│  ┌──────────────┐  ┌──────────────┐                                 │
│  │  Swingbench  │  │     AWR      │                                 │
│  │              │  │              │                                 │
│  │ - tps        │  │ - db_cpu     │                                 │
│  │ - tx_count   │  │ - log_sync   │                                 │
│  │ - response   │  │ - seq_read   │                                 │
│  │ - dml_stats  │  │ - redo_size  │                                 │
│  └──────────────┘  └──────────────┘                                 │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 2. DataFrame Schemas

#### FIO DataFrame

| Column | Type | Source | Description |
|--------|------|--------|-------------|
| sprint | int | path | Sprint number |
| phase | str | context | 'fio' |
| job_name | str | jobs[].jobname | data-8k, redo, fra-1m |
| read_bw_kbps | float | jobs[].read.bw | Read bandwidth KB/s |
| write_bw_kbps | float | jobs[].write.bw | Write bandwidth KB/s |
| read_iops | float | jobs[].read.iops | Read IOPS |
| write_iops | float | jobs[].write.iops | Write IOPS |
| read_lat_mean_us | float | jobs[].read.lat_ns.mean/1000 | Read latency |
| write_lat_mean_us | float | jobs[].write.lat_ns.mean/1000 | Write latency |
| read_lat_p99_us | float | jobs[].read.clat_ns.percentile['99.000000']/1000 | P99 latency |
| runtime_s | float | jobs[].job_runtime/1000 | Job runtime |

#### iostat DataFrame

| Column | Type | Source | Description |
|--------|------|--------|-------------|
| sprint | int | path | Sprint number |
| phase | str | context | 'fio' or 'swingbench' |
| timestamp | datetime | parsed | Sample time |
| device | str | json key | dm-4, sdb, etc. |
| reads_per_sec | float | r/s | Read operations/sec |
| writes_per_sec | float | w/s | Write operations/sec |
| read_kbps | float | rkB/s | Read KB/s |
| write_kbps | float | wkB/s | Write KB/s |
| util_pct | float | %util | Device utilization |

#### OCI Metrics DataFrame

| Column | Type | Source | Description |
|--------|------|--------|-------------|
| sprint | int | path | Sprint number |
| phase | str | context | 'fio' or 'swingbench' |
| timestamp | datetime | aggregated-datapoints[].timestamp | Metric time |
| resource_name | str | resource_name | data1, data2, redo1, etc. |
| resource_class | str | class | blockvolume, compute |
| metric_name | str | metric_name | VolumeReadThroughput, etc. |
| value | float | aggregated-datapoints[].value | Metric value |
| value_scaled | float | value/scale | Human-readable value |

#### Swingbench DataFrame

| Column | Type | Source | Description |
|--------|------|--------|-------------|
| sprint | int | path | Sprint number |
| timestamp | datetime | TPSReadings | Per-second timestamp |
| tps | float | TPSReadings | Transactions/second |
| tx_type | str | TransactionResults | Transaction name |
| tx_count | int | TransactionCount | Total transactions |
| avg_response_ms | float | AverageResponse | Mean response time |
| p90_response_ms | float | NinetiethPercentile | P90 response |

#### AWR Summary DataFrame

| Column | Type | Source | Description |
|--------|------|--------|-------------|
| sprint | int | path | Sprint number |
| begin_snap | int | awr_begin_snap_id.txt | Start snapshot |
| end_snap | int | awr_end_snap_id.txt | End snapshot |
| db_cpu_s | float | AWR report | DB CPU seconds |
| db_cpu_pct | float | AWR report | DB CPU percentage |
| log_sync_waits | int | AWR report | log file sync waits |
| log_sync_time_s | float | AWR report | Total wait time |
| log_sync_avg_us | float | AWR report | Avg wait microseconds |
| seq_read_waits | int | AWR report | db file sequential read waits |
| seq_read_time_s | float | AWR report | Total wait time |
| redo_size_gb | float | AWR report | Redo generated GB |
| phys_read_gb | float | AWR report | Physical read GB |
| phys_write_gb | float | AWR report | Physical write GB |

### 3. Correlation Techniques

#### 3.1 Pearson Correlation Matrix

```python
import pandas as pd
import numpy as np
from scipy import stats

def compute_correlation_matrix(aligned_df: pd.DataFrame) -> pd.DataFrame:
    """
    Compute Pearson correlation between observation layers.

    Expected columns:
    - fio_read_bw, fio_write_bw
    - iostat_read_kbps, iostat_write_kbps
    - oci_read_tp_mbps, oci_write_tp_mbps
    """
    metrics = [
        'fio_read_bw', 'fio_write_bw',
        'iostat_read_kbps', 'iostat_write_kbps',
        'oci_read_tp_mbps', 'oci_write_tp_mbps'
    ]

    available = [m for m in metrics if m in aligned_df.columns]
    return aligned_df[available].corr(method='pearson')
```

#### 3.1.1 Variable selection (resource-mapped, per phase)

To avoid redundancy and topology ambiguity, Sprint 19 correlation is based on **resource-mapped variables** computed from device/volume topology:

- **FIO phase**
  - Compare `fio_<resource>_mbps` ↔ `iostat_<resource>_mbps` ↔ `oci_<resource>_mbps` for resources: `data`, `redo`, `fra` (boot should normally be low)
  - Prefer a single normalized unit for throughput (MB/s) and keep one metric per concept (avoid both `*_kbps` and `*_mbps` representations).

- **Swingbench phase**
  - Compare `iostat_<resource>_mbps` ↔ `oci_<resource>_mbps` per resource
  - Treat `swing_tps_total` and optional `swing_tps_<tx_name>` as **diagnostic** variables and correlate primarily against AWR and aggregated storage, not as a primary pass/fail gate.

Resource examples:
- iostat: `iostat_boot_mbps`, `iostat_data_mbps`, `iostat_redo_mbps`, `iostat_fra_mbps`
- OCI BV: `oci_boot_mbps`, `oci_data1_mbps`, `oci_data2_mbps`, `oci_redo1_mbps`, `oci_redo2_mbps`, `oci_fra_mbps`
- FIO: `fio_data_mbps`, `fio_redo_mbps`, `fio_fra_mbps`

For multi-volume groups:
- `oci_data_mbps = oci_data1_mbps + oci_data2_mbps`
- `oci_redo_mbps = oci_redo1_mbps + oci_redo2_mbps`

#### 3.2 Spearman Rank Correlation

```python
def compute_rank_correlation(df: pd.DataFrame, col1: str, col2: str) -> tuple:
    """
    Compute Spearman rank correlation for non-linear relationships.
    Returns (correlation, p-value).
    """
    mask = df[[col1, col2]].notna().all(axis=1)
    if mask.sum() < 3:
        return (np.nan, np.nan)

    return stats.spearmanr(df.loc[mask, col1], df.loc[mask, col2])
```

#### 3.3 Quadrant Correlation Matrix

Bin continuous metrics into categories (Low/Medium/High) to visualize cross-layer agreement:

```python
from scipy.stats import chi2_contingency

def compute_quadrant_matrix(
    df: pd.DataFrame,
    col1: str,
    col2: str,
    thresholds1: tuple = (33, 66),  # percentiles
    thresholds2: tuple = (33, 66)
) -> dict:
    """
    Create contingency table and Chi-squared test for categorical correlation.

    Returns:
        dict with 'matrix', 'chi2', 'p_value', 'agreement_pct'
    """
    # Compute percentile thresholds
    t1 = df[col1].quantile([thresholds1[0]/100, thresholds1[1]/100])
    t2 = df[col2].quantile([thresholds2[0]/100, thresholds2[1]/100])

    def categorize(series, thresholds):
        return pd.cut(
            series,
            bins=[-np.inf, thresholds.iloc[0], thresholds.iloc[1], np.inf],
            labels=['Low', 'Medium', 'High']
        )

    df['cat1'] = categorize(df[col1], t1)
    df['cat2'] = categorize(df[col2], t2)

    # Contingency table
    matrix = pd.crosstab(df['cat1'], df['cat2'], margins=True)

    # Chi-squared test
    chi2, p_value, dof, expected = chi2_contingency(
        matrix.iloc[:-1, :-1]  # exclude margins
    )

    # Diagonal agreement percentage
    diagonal_sum = sum(
        matrix.loc[cat, cat] for cat in ['Low', 'Medium', 'High']
        if cat in matrix.index and cat in matrix.columns
    )
    total = matrix.loc['All', 'All']
    agreement_pct = (diagonal_sum / total) * 100 if total > 0 else 0

    return {
        'matrix': matrix,
        'chi2': chi2,
        'p_value': p_value,
        'agreement_pct': agreement_pct
    }
```

This reveals whether observation layers agree on activity levels (Low/Medium/High) even when absolute values differ due to measurement semantics.

#### 3.4 Time-Series Alignment

```python
def align_timeseries(
    fio_df: pd.DataFrame,
    iostat_df: pd.DataFrame,
    oci_df: pd.DataFrame,
    freq: str = '1min'
) -> pd.DataFrame:
    """
    Align all observation layers to common time index.

    Strategy:
    1. Resample iostat (typically 1s) to 1-minute means
    2. Use OCI metrics timestamps as reference (1-min resolution)
    3. Forward-fill FIO summary values across runtime
    """
    # Resample iostat to 1-minute buckets
    iostat_resampled = iostat_df.set_index('timestamp').resample(freq).mean()

    # OCI metrics already at 1-minute resolution
    oci_pivot = oci_df.pivot_table(
        index='timestamp',
        columns=['resource_name', 'metric_name'],
        values='value_scaled',
        aggfunc='mean'
    )

    # Merge on time index
    aligned = iostat_resampled.join(oci_pivot, how='outer')

    return aligned.reset_index()
```

#### 3.5 Lagged correlation (iostat ↔ OCI)

Because OCI metrics are 1-minute aggregated and may be time-shifted relative to guest observation, compute lagged correlations for matched resource pairs:
- lags: \(\pm\) 0..5 minutes (configurable)
- select best lag by absolute Pearson r (report lag + r + p-value, plus Spearman)
- report N aligned samples used for that lag

#### 3.6 Decision: alignment resolution for short runs / sample_idx-only iostat

Some sprints (e.g., Sprint 17) capture iostat as sysstat JSON with **`sample_idx` only** (no timestamps). The benchmark harness uses:
- `iostat -xdmz 10 ... -o JSON` → **10 second sampling interval**

**Decision:**
- Correlation is computed at **OCI native 1-minute resolution**.
- If iostat has real timestamps → resample to 1-minute using mean aggregation over time buckets.
- If iostat has only `sample_idx` → reconstruct timestamps relative to the first OCI timestamp using the harness sampling interval, then resample to 1-minute:
  - \(t(i) = t_0 + i \cdot 10s\)
- If the 1-minute correlation becomes undefined due to constant-series artifacts (common in short or sparse windows), compute correlation on **10-second cadence** with OCI expanded by forward-fill as a **fallback diagnostic**.

**Rationale:**
- Index-based merging is not time alignment and produces nonsensical correlations.
- 1-minute is the only resolution where OCI metrics have independent observations; comparing at higher cadence requires interpolation/ffill and is treated as optional drill-down, not the primary evidence gate.

### 4. Anomaly Detection Rules

#### Rule Engine

```python
from dataclasses import dataclass
from typing import List, Callable
import pandas as pd

@dataclass
class AnomalyRule:
    id: str
    name: str
    description: str
    severity: str  # 'critical', 'warning', 'info'
    check_fn: Callable[[pd.DataFrame], bool]
    message_fn: Callable[[pd.DataFrame], str]

class AnomalyDetector:
    def __init__(self):
        self.rules: List[AnomalyRule] = []
        self._register_default_rules()

    def _register_default_rules(self):
        # R1: iostat active but OCI metrics zero
        self.rules.append(AnomalyRule(
            id='R1',
            name='iostat_oci_mismatch',
            description='Guest iostat shows activity but OCI block volume metrics are zero',
            severity='critical',
            check_fn=self._check_iostat_oci_mismatch,
            message_fn=lambda df: f"iostat avg {df['iostat_write_kbps'].mean():.1f} KB/s but OCI write {df['oci_write_tp_mbps'].mean():.2f} MB/s"
        ))

        # R2: FIO target mismatch
        self.rules.append(AnomalyRule(
            id='R2',
            name='fio_topology_mismatch',
            description='FIO target device does not match iostat active devices',
            severity='critical',
            check_fn=self._check_fio_topology,
            message_fn=lambda df: "FIO targeting different devices than iostat observed"
        ))

        # R3: Swingbench TPS but no block volume activity
        self.rules.append(AnomalyRule(
            id='R3',
            name='swingbench_no_bv_io',
            description='Swingbench shows stable TPS but block volume OCI metrics are zero',
            severity='critical',
            check_fn=self._check_swingbench_bv_activity,
            message_fn=lambda df: f"Swingbench TPS {df['tps'].mean():.0f} but block volumes show no I/O"
        ))

        # R4: Redo placement check
        self.rules.append(AnomalyRule(
            id='R4',
            name='redo_placement_defect',
            description='AWR shows redo activity but redo volume OCI metrics zero',
            severity='critical',
            check_fn=self._check_redo_placement,
            message_fn=lambda df: "Redo generated but redo volumes show no write activity"
        ))

        # R5: Cross-layer correlation too low
        self.rules.append(AnomalyRule(
            id='R5',
            name='low_correlation',
            description='Cross-layer correlation below 0.5 threshold',
            severity='warning',
            check_fn=self._check_correlation_threshold,
            message_fn=lambda df: f"Cross-layer correlation {df['correlation'].iloc[0]:.2f} below 0.5"
        ))

    def _check_iostat_oci_mismatch(self, df: pd.DataFrame) -> bool:
        iostat_active = df['iostat_write_kbps'].mean() > 100  # > 100 KB/s
        oci_idle = df['oci_write_tp_mbps'].mean() < 1  # < 1 MB/s
        return iostat_active and oci_idle

    def _check_fio_topology(self, df: pd.DataFrame) -> bool:
        # Check if expected devices match observed devices
        # Returns True if mismatch detected
        return False  # Implement based on topology metadata

    def _check_swingbench_bv_activity(self, df: pd.DataFrame) -> bool:
        if 'tps' not in df.columns:
            return False
        tps_active = df['tps'].mean() > 100
        bv_idle = df.get('oci_data_write_mbps', pd.Series([0])).mean() < 1
        return tps_active and bv_idle

    def _check_redo_placement(self, df: pd.DataFrame) -> bool:
        # Check AWR redo_size > 0 but redo volumes show no writes
        return False  # Implement with AWR integration

    def _check_correlation_threshold(self, df: pd.DataFrame) -> bool:
        if 'correlation' not in df.columns:
            return False
        return df['correlation'].iloc[0] < 0.5

    def detect(self, df: pd.DataFrame) -> List[dict]:
        """Run all rules and return detected anomalies."""
        anomalies = []
        for rule in self.rules:
            try:
                if rule.check_fn(df):
                    anomalies.append({
                        'rule_id': rule.id,
                        'rule_name': rule.name,
                        'severity': rule.severity,
                        'description': rule.description,
                        'message': rule.message_fn(df)
                    })
            except Exception as e:
                pass  # Rule not applicable to this data
        return anomalies
```

### 5. Evidence Quality Scoring

```python
@dataclass
class EvidenceQualityReport:
    sprint: int
    phase: str
    score: int  # 0-100
    grade: str  # A, B, C, D, F
    cross_layer_correlation: float
    anomaly_count: int
    critical_anomalies: int
    topology_match: bool
    time_coverage_pct: float
    pass_fail: str
    findings: List[str]

def compute_evidence_quality(
    sprint: int,
    phase: str,
    aligned_df: pd.DataFrame,
    anomalies: List[dict]
) -> EvidenceQualityReport:
    """
    Score evidence quality on 0-100 scale.

    Scoring:
    - Cross-layer correlation >= 0.7: +25 points
    - No critical anomalies: +25 points
    - Topology match (expected devices active): +25 points
    - Time coverage >= 80%: +25 points

    Grades:
    - A: 90-100 (Strong evidence)
    - B: 75-89 (Acceptable evidence)
    - C: 50-74 (Weak evidence)
    - D: 25-49 (Insufficient evidence)
    - F: 0-24 (Failed evidence)

    Pass/Fail:
    - PASS: Grade A or B with no critical anomalies
    - INCONCLUSIVE: Grade C or critical anomalies
    - FAIL: Grade D or F
    """
    score = 0
    findings = []

    # 1. Cross-layer correlation
    try:
        corr_matrix = aligned_df[['iostat_write_kbps', 'oci_write_tp_mbps']].corr()
        cross_corr = corr_matrix.iloc[0, 1]
        if pd.notna(cross_corr) and cross_corr >= 0.7:
            score += 25
            findings.append(f"Cross-layer correlation {cross_corr:.2f} >= 0.7 threshold")
        else:
            findings.append(f"Cross-layer correlation {cross_corr:.2f} below 0.7 threshold")
    except:
        cross_corr = np.nan
        findings.append("Cross-layer correlation: insufficient data")

    # 2. Anomaly check
    critical_count = sum(1 for a in anomalies if a['severity'] == 'critical')
    if critical_count == 0:
        score += 25
        findings.append("No critical anomalies detected")
    else:
        findings.append(f"{critical_count} critical anomalies detected")

    # 3. Topology match
    topology_ok = True  # Simplified; implement device mapping check
    if topology_ok:
        score += 25
        findings.append("Expected storage topology matches observed devices")

    # 4. Time coverage
    # Coverage is derived from phase window length and sampling frequency.
    # expected_points = number of 1-min buckets in the phase window.
    # actual_points = number of buckets with non-null OCI data for the matched resource(s).
    expected_points = 15  # placeholder in pseudocode; implement derived expected_points
    actual_points = len(aligned_df.dropna(subset=['oci_write_tp_mbps']))
    coverage = actual_points / expected_points if expected_points > 0 else 0
    if coverage >= 0.8:
        score += 25
        findings.append(f"Time coverage {coverage*100:.0f}% >= 80% threshold")
    else:
        findings.append(f"Time coverage {coverage*100:.0f}% below 80% threshold")

    # Compute grade
    if score >= 90:
        grade = 'A'
    elif score >= 75:
        grade = 'B'
    elif score >= 50:
        grade = 'C'
    elif score >= 25:
        grade = 'D'
    else:
        grade = 'F'

    # Determine pass/fail
    if grade in ['A', 'B'] and critical_count == 0:
        pass_fail = 'PASS'
    elif grade == 'C' or critical_count > 0:
        pass_fail = 'INCONCLUSIVE'
    else:
        pass_fail = 'FAIL'

    return EvidenceQualityReport(
        sprint=sprint,
        phase=phase,
        score=score,
        grade=grade,
        cross_layer_correlation=cross_corr if pd.notna(cross_corr) else 0.0,
        anomaly_count=len(anomalies),
        critical_anomalies=critical_count,
        topology_match=topology_ok,
        time_coverage_pct=coverage * 100,
        pass_fail=pass_fail,
        findings=findings
    )
```

### 6. Visualization Components

```python
import matplotlib.pyplot as plt
import seaborn as sns

def plot_correlation_heatmap(corr_matrix: pd.DataFrame, output_path: str):
    """Generate correlation heatmap."""
    fig, ax = plt.subplots(figsize=(10, 8))
    sns.heatmap(
        corr_matrix,
        annot=True,
        fmt='.2f',
        cmap='RdYlGn',
        center=0,
        vmin=-1,
        vmax=1,
        ax=ax
    )
    ax.set_title('Cross-Layer Correlation Matrix')
    plt.tight_layout()
    plt.savefig(output_path, dpi=150)
    plt.close()

def plot_timeseries_comparison(
    aligned_df: pd.DataFrame,
    output_path: str
):
    """Generate multi-panel time-series comparison."""
    fig, axes = plt.subplots(3, 1, figsize=(14, 10), sharex=True)

    # Panel 1: iostat throughput
    axes[0].plot(aligned_df['timestamp'], aligned_df['iostat_write_kbps']/1024,
                 label='iostat write MB/s', color='blue')
    axes[0].set_ylabel('MB/s')
    axes[0].legend()
    axes[0].set_title('Guest iostat Throughput')

    # Panel 2: OCI metrics
    axes[1].plot(aligned_df['timestamp'], aligned_df['oci_write_tp_mbps'],
                 label='OCI write MB/s', color='orange')
    axes[1].set_ylabel('MB/s')
    axes[1].legend()
    axes[1].set_title('OCI Block Volume Throughput')

    # Panel 3: Swingbench TPS (if available)
    if 'tps' in aligned_df.columns:
        axes[2].plot(aligned_df['timestamp'], aligned_df['tps'],
                     label='TPS', color='green')
        axes[2].set_ylabel('TPS')
        axes[2].legend()
        axes[2].set_title('Swingbench Transaction Rate')

    plt.xlabel('Time')
    plt.tight_layout()
    plt.savefig(output_path, dpi=150)
    plt.close()
```

### 7. Implementation Structure

```
tools/
└── analysis/
    ├── __init__.py
    ├── loaders/
    │   ├── __init__.py
    │   ├── fio_loader.py
    │   ├── iostat_loader.py
    │   ├── oci_metrics_loader.py
    │   ├── swingbench_loader.py
    │   └── awr_loader.py
    ├── correlation/
    │   ├── __init__.py
    │   ├── time_alignment.py
    │   ├── correlation_engine.py
    │   └── anomaly_detector.py
    ├── reporting/
    │   ├── __init__.py
    │   ├── quality_scorer.py
    │   ├── visualizations.py
    │   └── report_generator.py
    └── analyze_sprint.py  # CLI entry point

progress/sprint_19/
├── correlation_report.md
├── correlation_heatmap.png
├── timeseries_comparison_s17_fio.png
├── timeseries_comparison_s17_sb.png
├── timeseries_comparison_s18_fio.png
├── timeseries_comparison_s18_sb.png
├── evidence_quality_scores.csv
└── sprint_validation_results.md
```

### 8. CLI Interface

```bash
# Analyze single sprint
python tools/analysis/analyze_sprint.py --sprint 18 --phase fio

# Analyze all sprints
python tools/analysis/analyze_sprint.py --all

# Generate comparison report
python tools/analysis/analyze_sprint.py --compare 17,18 --output report.html
```

## Test Specification

### Test Strategy

| Level | Focus | Count |
|-------|-------|-------|
| Integration | End-to-end analysis pipeline | 3 |

### Integration Tests

#### IT-1: FIO Data Loading and Parsing

**Purpose:** Verify FIO JSON parser extracts all required metrics.

**Input:** `progress/sprint_18/fio_results.json`

**Expected:** DataFrame with correct schema, non-null values for key metrics.

```python
def test_fio_loader():
    df = load_fio_results('progress/sprint_18/fio_results.json')
    assert len(df) > 0
    assert 'job_name' in df.columns
    assert 'read_bw_kbps' in df.columns
    assert df['read_bw_kbps'].notna().all()
```

#### IT-2: Cross-Layer Correlation Calculation

**Purpose:** Verify correlation engine produces valid correlation matrix.

**Input:** Aligned DataFrame with iostat and OCI metrics.

**Expected:** Correlation values in [-1, 1] range.

```python
def test_correlation_engine():
    aligned_df = align_timeseries(iostat_df, oci_df)
    corr = compute_correlation_matrix(aligned_df)
    assert corr.min().min() >= -1.0
    assert corr.max().max() <= 1.0
```

#### IT-3: Anomaly Detection on Known Failure

**Purpose:** Verify anomaly detector catches Sprint 17/18 Swingbench placement issue.

**Input:** Sprint 18 Swingbench phase data (known to have near-zero block volume metrics).

**Expected:** Rule R3 (swingbench_no_bv_io) triggers critical anomaly.

```python
def test_anomaly_detection_swingbench():
    df = load_sprint_18_swingbench_data()
    detector = AnomalyDetector()
    anomalies = detector.detect(df)
    r3_triggered = any(a['rule_id'] == 'R3' for a in anomalies)
    assert r3_triggered, "R3 should detect Swingbench without BV I/O"
```

### Test Manifest

```
tests/integration/test_sprint19_analysis.py::test_fio_loader
tests/integration/test_sprint19_analysis.py::test_correlation_engine
tests/integration/test_sprint19_analysis.py::test_anomaly_detection_swingbench
```

## Acceptance Criteria

### Primary Deliverables

1. **Python analysis framework** in `tools/analysis/`
2. **Correlation report** for Sprints 15, 17, 18 in `progress/sprint_19/`
3. **Evidence quality scores** for all analyzed sprints
4. **Anomaly detection results** with rule violations documented
5. **Sprint validation verdicts** (PASS/INCONCLUSIVE/FAIL)

### Evidence Quality Rules (Outcome)

The following rules will be defined and documented:

| Rule | Criterion | Threshold | Action |
|------|-----------|-----------|--------|
| EQ-1 | Cross-layer correlation | >= 0.7 | Required for PASS |
| EQ-2 | No critical anomalies | 0 | Required for PASS |
| EQ-3 | Topology match | 100% | Required for PASS |
| EQ-4 | Time coverage | >= 80% | Required for PASS |
| EQ-5 | OCI metrics non-zero | Active resources > 0 | Required for PASS |

### Expected Outcomes

Based on preliminary data review:

| Sprint | Phase | Expected Verdict | Reason |
|--------|-------|------------------|--------|
| 15 | Swingbench | Unknown | Single-volume, may have placement issue |
| 17 | FIO | PASS | Strong FIO-to-OCI correlation observed |
| 17 | Swingbench | INCONCLUSIVE | OCI metrics nearly zero (short run) |
| 18 | FIO | PASS | Strong FIO-to-OCI correlation observed |
| 18 | Swingbench | FAIL | OCI metrics zero despite 15-min run (R3 violation) |

## Dependencies

### Python Packages

```
pandas>=1.5.0
numpy>=1.24.0
matplotlib>=3.7.0
seaborn>=0.12.0
scipy>=1.10.0
```

### Installation

```bash
pip install pandas numpy matplotlib seaborn scipy
```

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| AWR parsing complexity | Medium | Low | Start with manual extraction, automate later |
| Time-zone alignment issues | Medium | Medium | Normalize all timestamps to UTC |
| Insufficient data points | Low | High | Use interpolation for sparse data |
| False positive anomalies | Medium | Low | Tune thresholds based on findings |
