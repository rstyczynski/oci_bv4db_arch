# Sprint 17 - Correlation Analysis Report

**Generated:** 2026-04-24 11:35:07

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Phase 1: FIO Storage Benchmark](#phase-1-fio-storage-benchmark)
   - [FIO Performance Summary](#fio-performance-summary)
   - [FIO Cross-Layer Correlation](#fio-cross-layer-correlation)
   - [FIO Full Correlation Matrix](#fio-full-correlation-matrix)
3. [Phase 2: Swingbench Database Workload](#phase-2-swingbench-database-workload)
   - [Swingbench Performance Summary](#swingbench-performance-summary)
   - [Swingbench Cross-Layer Correlation](#swingbench-cross-layer-correlation)
   - [Swingbench Full Correlation Matrix](#swingbench-full-correlation-matrix)
4. [Cross-Phase Comparison](#cross-phase-comparison)
5. [Compute Resource Utilization](#compute-resource-utilization)
6. [Anomalies and Findings](#anomalies-and-findings)
7. [Conclusion](#conclusion)

---

## Executive Summary

Sprint 17 benchmark analysis examines cross-layer correlation between:
- **Guest OS measurements** (iostat)
- **OCI Block Volume metrics** (Monitoring API)
- **Workload metrics** (FIO throughput, Swingbench TPS)

### Overall Results

| Phase | Score | Grade | Verdict |
|-------|-------|-------|---------|
| FIO (Storage) | 75/100 | B | PASS |
| Swingbench (Database) | 35/100 | D | FAIL |

---

## Phase 1: FIO Storage Benchmark

FIO (Flexible I/O Tester) provides direct storage-level benchmarking without database overhead.

### FIO Performance Summary

| Job | Read BW (MB/s) | Write BW (MB/s) | Read IOPS | Write IOPS | Read Lat P99 (ms) | Write Lat P99 (ms) |
|-----|----------------|-----------------|-----------|------------|-------------------|-------------------|
| data-8k | 103.1 | 44.3 | 13200 | 5664 | 1.74 | 2.07 |
| data-8k | 103.2 | 44.1 | 13212 | 5647 | 1.74 | 2.07 |
| data-8k | 103.3 | 44.2 | 13219 | 5655 | 1.74 | 2.07 |
| data-8k | 103.2 | 44.1 | 13214 | 5648 | 1.74 | 2.07 |
| redo | 0.0 | 2.8 | 0 | 706 | 0.00 | 0.71 |
| fra-1m | 23.7 | 23.1 | 24 | 23 | 278.92 | 283.12 |

### FIO Cross-Layer Correlation

Correlation between guest iostat measurements and OCI Block Volume metrics.

| Metric | iostat vs OCI |
|--------|---------------|
| Pearson r | -0.822 |
| Pearson p-value | 0.0010 |
| Spearman ρ | -0.579 |
| Spearman p-value | 0.0484 |
| Aligned Samples | 12 |

### FIO iostat vs OCI Block Volumes

### iostat vs OCI Block Volumes

| Volume | Pearson r | p-value | iostat (MB/s) | OCI (MB/s) | Match |
|--------|-----------|---------|---------------|------------|-------|
| data1 | -0.822 | 0.0010 | 907.6 | 1761.4 | Strong |
| fra | 0.822 | 0.0010 | 907.6 | 1075.7 | Strong |
| redo1 | 0.822 | 0.0010 | 907.6 | 405.5 | Strong |
| redo2 | -0.822 | 0.0010 | 907.6 | 282.2 | Strong |
| data2 | -0.822 | 0.0010 | 907.6 | 1055.5 | Strong |

**Best match:** `data1` (r = -0.822)

### Per-Volume Type Correlation

Correlation between iostat per-volume metrics and matching OCI volumes:

| iostat Volume | OCI Volume | Pearson r | p-value | iostat (MB/s) | OCI (MB/s) |
|---------------|------------|-----------|---------|---------------|------------|
| data | data1 | -0.831 | 0.0008 | 717.0 | 1761.4 |
| data | data2 | -0.831 | 0.0008 | 717.0 | 1055.5 |
| fra | fra | N/A | N/A | 0.0 | 1075.7 |
| redo | redo1 | 0.819 | 0.0011 | 152.9 | 405.5 |
| redo | redo2 | -0.819 | 0.0011 | 152.9 | 282.2 |

### Lagged Per-Volume Correlation (Best Lag)

Best Pearson correlation over lag ±0..5 minutes for each iostat↔OCI matched pair.

| iostat Volume | OCI Volume | Best Lag (min) | Pearson r | p-value | N |
|---------------|------------|----------------|-----------|---------|---|
| data | data1 | 1 | -0.849 | 0.0010 | 11 |
| data | data2 | 1 | -0.849 | 0.0010 | 11 |
| redo | redo1 | 1 | 0.874 | 0.0004 | 11 |
| redo | redo2 | 1 | -0.874 | 0.0004 | 11 |

### iostat vs Compute DiskBytesWritten
- Pearson r: -0.822 (p = 0.0010)
- iostat mean: 907.6 MB/s
- Compute DiskBytes mean: 334.7 MB/s

### FIO Full Correlation Matrix

Pearson correlations between all available metrics:

| Variable | io_boot_mbps | io_data_mbps | io_redo_mbps | oci_data_mbps | oci_redo_mbps | oci_fra_mbps | fio_data_mbps | fio_redo_mbps |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| io_boot_mbps | 1.00 | 0.27 | 0.27 | *-0.58* | *-0.58* | *0.58* | 0.27 | 0.27 |
| io_data_mbps | 0.27 | 1.00 | **1.00** | **-0.83** | **-0.83** | **0.83** | **1.00** | **1.00** |
| io_redo_mbps | 0.27 | **1.00** | 1.00 | **-0.82** | **-0.82** | **0.82** | **1.00** | **1.00** |
| oci_data_mbps | *-0.58* | **-0.83** | **-0.82** | 1.00 | **1.00** | **-1.00** | **-0.83** | **-0.82** |
| oci_redo_mbps | *-0.58* | **-0.83** | **-0.82** | **1.00** | 1.00 | **-1.00** | **-0.83** | **-0.82** |
| oci_fra_mbps | *0.58* | **0.83** | **0.82** | **-1.00** | **-1.00** | 1.00 | **0.83** | **0.82** |
| fio_data_mbps | 0.27 | **1.00** | **1.00** | **-0.83** | **-0.83** | **0.83** | 1.00 | **1.00** |
| fio_redo_mbps | 0.27 | **1.00** | **1.00** | **-0.82** | **-0.82** | **0.82** | **1.00** | 1.00 |

*Bold: |r| >= 0.7, Italic: |r| >= 0.5*

### FIO Significant Correlations

| Variable 1 | Variable 2 | Pearson r | p-value | n | Strength |
|------------|------------|-----------|---------|---:|----------|
| oci_redo_mbps | oci_fra_mbps | -1.000 | 0.0000 | 12 | strong |
| oci_data_mbps | oci_redo_mbps | 1.000 | 0.0000 | 12 | strong |
| oci_data_mbps | oci_fra_mbps | -1.000 | 0.0000 | 12 | strong |
| io_data_mbps | fio_data_mbps | 1.000 | 0.0000 | 12 | strong |
| io_redo_mbps | fio_redo_mbps | 1.000 | 0.0000 | 12 | strong |
| io_redo_mbps | fio_data_mbps | 0.999 | 0.0000 | 12 | strong |
| io_data_mbps | io_redo_mbps | 0.999 | 0.0000 | 12 | strong |
| fio_data_mbps | fio_redo_mbps | 0.999 | 0.0000 | 12 | strong |
| io_data_mbps | fio_redo_mbps | 0.999 | 0.0000 | 12 | strong |
| oci_data_mbps | fio_fra_mbps | 0.903 | 0.0001 | 12 | strong |

---

## Phase 2: Swingbench Database Workload

Swingbench generates OLTP database workload against Oracle Database Free.

### Swingbench Performance Summary

| Metric | Value |
|--------|-------|
| Average TPS | 2115.7 |
| Completed Transactions | 126,939 |
| iostat Samples | 103 |
| OCI Metrics Entries | 112 |

### Swingbench Cross-Layer Correlation

Correlation between guest iostat measurements and OCI Block Volume metrics during database workload.

| Metric | iostat vs OCI |
|--------|---------------|
| Pearson r | nan |
| Pearson p-value | nan |
| Spearman ρ | nan |
| Spearman p-value | nan |
| Aligned Samples | 12 |

### Swingbench iostat vs OCI Block Volumes

### iostat vs OCI Block Volumes

| Volume | Pearson r | p-value | iostat (MB/s) | OCI (MB/s) | Match |
|--------|-----------|---------|---------------|------------|-------|
| data1 | N/A | N/A | 87.6 | 0.0 | None |
| data2 | N/A | N/A | 87.6 | 0.0 | None |
| fra | N/A | N/A | 87.6 | 0.0 | None |
| redo1 | N/A | N/A | 87.6 | 0.0 | None |
| redo2 | N/A | N/A | 87.6 | 0.0 | None |

**Best match:** `data1` (r = nan)

### Per-Volume Type Correlation

Correlation between iostat per-volume metrics and matching OCI volumes:

| iostat Volume | OCI Volume | Pearson r | p-value | iostat (MB/s) | OCI (MB/s) |
|---------------|------------|-----------|---------|---------------|------------|
| data | data1 | N/A | N/A | 18.2 | 0.0 |
| data | data2 | N/A | N/A | 18.2 | 0.0 |
| fra | fra | N/A | N/A | 0.0 | 0.0 |
| redo | redo1 | N/A | N/A | 4.1 | 0.0 |
| redo | redo2 | N/A | N/A | 4.1 | 0.0 |

### iostat vs Compute DiskBytesWritten
- Pearson r: 0.563 (p = 0.0564)
- iostat mean: 87.6 MB/s
- Compute DiskBytes mean: 34.9 MB/s

### Swingbench Full Correlation Matrix

Pearson correlations between all available metrics:

| Variable | io_boot_mbps | io_data_mbps | io_redo_mbps | tps |
| --- | --- | --- | --- | --- |
| io_boot_mbps | 1.00 | **-0.82** | **-0.82** | **-0.80** |
| io_data_mbps | **-0.82** | 1.00 | **1.00** | **1.00** |
| io_redo_mbps | **-0.82** | **1.00** | 1.00 | **1.00** |
| tps | **-0.80** | **1.00** | **1.00** | 1.00 |

*Bold: |r| >= 0.7, Italic: |r| >= 0.5*

**Warning:** some correlations are computed on a small overlap (min n = 5). Values based on n < 10 are not statistically meaningful (small-n can yield |r| close to 1.00).

---

## Cross-Phase Comparison

Comparison of correlation strength between storage-level (FIO) and database-level (Swingbench) workloads.

| Metric | FIO Phase | Swingbench Phase | Interpretation |
|--------|-----------|------------------|----------------|
| Pearson r | -0.822 | nan | FIO: strong, Swingbench: undefined |
| Best Volume Match | data1 (r=-0.82) | N/A | Which volume shows highest correlation with iostat |
| Aligned Samples | 12 | 12 | - |

**Observations:**

- Correlation patterns require further investigation

---

## Compute Resource Utilization

OCI Compute instance metrics during benchmark phases.

| Metric | FIO Phase | Swingbench Phase |
|--------|-----------|------------------|
| CpuUtilization | 1.5% | 2.7% |
| MemoryUtilization | 4.1% | 6.6% |
| DiskBytesRead | 57.6 MB/s | 0.0 MB/s |
| DiskBytesWritten | 141.9 MB/s | 32.0 MB/s |

---

## Anomalies and Findings

| Phase | Rule | Severity | Message |
|-------|------|----------|---------|
| Swingbench | R6 | critical | Boot throughput dominates: boot=37.5 MB/s vs data+redo+fra=19.9 MB/s (ratio=1.89). Likely DB files on boot volume. |

---

## Conclusion

### Sprint 17 Evidence Quality Assessment

**Overall Verdict: PARTIAL**

One phase demonstrates acceptable evidence quality while the other requires review.

### Key Takeaways

- FIO phase shows weak cross-layer correlation (r=-0.82) - investigate
- Swingbench achieved 2116 TPS average throughput
