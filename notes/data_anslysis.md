# Data analysis

## Goal

- Make correlation trustworthy.
- Make failures explicit.

## What failed

- Sprint 17 Swingbench wrote to boot.
- Runs were too short.
- Overlap `n` was too small.
- FIO time series was missing.

## Next sprint plan

### Variable aggregation

Raw metrics are aggregated to topology level.

- aggregate `data1+data2 -> data`.
- aggregate `redo1+redo2 -> redo`.
- keep `boot -> boot`.
- keep `fra -> fra`.

Aggregation is defined by a mapping document.

### Keep topology variables only

Keep variables on `boot/data/redo/fra` only.

- Keep metric suffix as `dx`.
- `dx` means **change over time** (delta), not a metric family.
- Base metrics: `mbps`, `iops`.
- Delta metrics: `d_mbps`, `d_iops`.
- Parse FIO logs into `fio_<res>_<metric>` and `fio_<res>_<d_metric>`.
- Parse iostat into `iostat_<res>_<metric>` and `iostat_<res>_<d_metric>`.
- Parse OCI metrics into `oci_<res>_<metric>` and `oci_<res>_<d_metric>`.

### Correlations

- Correlate base with base (mbps ↔ mbps, iops ↔ iops).
- Correlate delta with delta (d_mbps ↔ d_mbps, d_iops ↔ d_iops).
- Use base ↔ delta only as a secondary check.
- Use `n` overlap as a guardrail.
- Keep only topology variables in the matrix.

### Capture metrics with timestamps

- Record phase start/end timestamps.
- FIO must be captured with timestamps.
- iostat must be captured with timestamps.
- Swingbench tps must be captured with timestamps.
- AWR is captured several times over a period of test.
  
## Number of data points

- One point can match. One point can’t prove correlation.
- Correlation needs variance across time.
- Pearson/Spearman need \(n \ge 3\) with non-constant series.
