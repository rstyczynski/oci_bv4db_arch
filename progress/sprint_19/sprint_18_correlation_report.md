# Sprint 18 - Correlation Analysis Report

**Generated:** 2026-04-24 11:27:27

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

Sprint 18 benchmark analysis examines cross-layer correlation between:
- **Guest OS measurements** (iostat)
- **OCI Block Volume metrics** (Monitoring API)
- **Workload metrics** (FIO throughput, Swingbench TPS)

### Overall Results

| Phase | Score | Grade | Verdict |
|-------|-------|-------|---------|
| FIO (Storage) | 100/100 | A | PASS |
| Swingbench (Database) | 100/100 | A | PASS |

---

## Phase 1: FIO Storage Benchmark

FIO (Flexible I/O Tester) provides direct storage-level benchmarking without database overhead.

### FIO Performance Summary

| Job | Read BW (MB/s) | Write BW (MB/s) | Read IOPS | Write IOPS | Read Lat P99 (ms) | Write Lat P99 (ms) |
|-----|----------------|-----------------|-----------|------------|-------------------|-------------------|
| data-8k | 56.7 | 24.3 | 7264 | 3113 | 5.41 | 6.32 |
| data-8k | 56.8 | 24.3 | 7266 | 3113 | 5.41 | 6.32 |
| data-8k | 56.8 | 24.3 | 7267 | 3112 | 5.41 | 6.32 |
| data-8k | 56.8 | 24.3 | 7270 | 3110 | 5.41 | 6.32 |
| redo | 0.0 | 2.7 | 0 | 689 | 0.00 | 1.12 |
| fra-1m | 11.9 | 11.6 | 12 | 12 | 599.79 | 624.95 |

### FIO Cross-Layer Correlation

Correlation between guest iostat measurements and OCI Block Volume metrics.

| Metric | iostat vs OCI |
|--------|---------------|
| Pearson r | 0.781 |
| Pearson p-value | 0.0004 |
| Spearman ρ | 0.285 |
| Spearman p-value | 0.2841 |
| Aligned Samples | 18 |

### FIO iostat vs OCI Block Volumes

### iostat vs OCI Block Volumes

| Volume | Pearson r | p-value | iostat (MB/s) | OCI (MB/s) | Match |
|--------|-----------|---------|---------------|------------|-------|
| redo2 | 0.833 | 0.0001 | 594.6 | 450.5 | Strong |
| data1 | 0.781 | 0.0004 | 594.6 | 984.6 | Strong |
| data2 | 0.742 | 0.0010 | 594.6 | 989.2 | Strong |
| redo1 | 0.720 | 0.0017 | 594.6 | 433.1 | Strong |
| fra | -0.549 | 0.0277 | 594.6 | 1715.8 | Moderate |

**Best match:** `redo2` (r = 0.833)

### Per-Volume Type Correlation

Correlation between iostat per-volume metrics and matching OCI volumes:

| iostat Volume | OCI Volume | Pearson r | p-value | iostat (MB/s) | OCI (MB/s) |
|---------------|------------|-----------|---------|---------------|------------|
| data | data1 | 0.843 | 0.0000 | 445.7 | 984.6 |
| data | data2 | 0.819 | 0.0001 | 445.7 | 989.2 |
| fra | fra | N/A | N/A | 0.0 | 1715.8 |
| redo | redo1 | 0.857 | 0.0000 | 105.2 | 433.1 |
| redo | redo2 | 0.910 | 0.0000 | 105.2 | 450.5 |

### Lagged Per-Volume Correlation (Best Lag)

Best Pearson correlation over lag ±0..5 minutes for each iostat↔OCI matched pair.

| iostat Volume | OCI Volume | Best Lag (min) | Pearson r | p-value | N |
|---------------|------------|----------------|-----------|---------|---|
| data | data1 | -1 | 0.902 | 0.0000 | 16 |
| data | data2 | -1 | 0.874 | 0.0000 | 16 |
| redo | redo1 | -1 | 0.891 | 0.0000 | 16 |
| redo | redo2 | 0 | 0.910 | 0.0000 | 16 |

### iostat vs Compute DiskBytesWritten
- Pearson r: 0.797 (p = 0.0002)
- iostat mean: 594.6 MB/s
- Compute DiskBytes mean: 209.5 MB/s

### FIO Full Correlation Matrix

Pearson correlations between all available metrics:

| Variable | io_boot_mbps | io_data_mbps | io_redo_mbps | oci_data_mbps | oci_redo_mbps | oci_fra_mbps | fio_data_mbps | fio_redo_mbps |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| io_boot_mbps | 1.00 | -0.06 | -0.05 | 0.07 | 0.06 | 0.07 | -0.07 | -0.06 |
| io_data_mbps | -0.06 | 1.00 | **1.00** | **0.85** | **0.87** | 0.09 | **1.00** | **1.00** |
| io_redo_mbps | -0.05 | **1.00** | 1.00 | **0.86** | **0.89** | 0.06 | **1.00** | **1.00** |
| oci_data_mbps | 0.07 | **0.85** | **0.86** | 1.00 | **0.87** | -0.07 | **0.84** | **0.86** |
| oci_redo_mbps | 0.06 | **0.87** | **0.89** | **0.87** | 1.00 | -0.15 | **0.86** | **0.88** |
| oci_fra_mbps | 0.07 | 0.09 | 0.06 | -0.07 | -0.15 | 1.00 | 0.10 | 0.07 |
| fio_data_mbps | -0.07 | **1.00** | **1.00** | **0.84** | **0.86** | 0.10 | 1.00 | **1.00** |
| fio_redo_mbps | -0.06 | **1.00** | **1.00** | **0.86** | **0.88** | 0.07 | **1.00** | 1.00 |

*Bold: |r| >= 0.7, Italic: |r| >= 0.5*

### FIO Significant Correlations

| Variable 1 | Variable 2 | Pearson r | p-value | Strength |
|------------|------------|-----------|---------|----------|
| io_redo_mbps | fio_redo_mbps | 1.000 | 0.0000 | strong |
| io_data_mbps | fio_data_mbps | 1.000 | 0.0000 | strong |
| io_data_mbps | fio_redo_mbps | 0.999 | 0.0000 | strong |
| io_data_mbps | io_redo_mbps | 0.999 | 0.0000 | strong |
| fio_data_mbps | fio_redo_mbps | 0.999 | 0.0000 | strong |
| io_redo_mbps | fio_data_mbps | 0.998 | 0.0000 | strong |
| io_redo_mbps | oci_redo_mbps | 0.886 | 0.0000 | strong |
| oci_redo_mbps | fio_redo_mbps | 0.880 | 0.0000 | strong |
| oci_data_mbps | oci_redo_mbps | 0.875 | 0.0000 | strong |
| io_data_mbps | oci_redo_mbps | 0.870 | 0.0000 | strong |

---

## Phase 2: Swingbench Database Workload

Swingbench generates OLTP database workload against Oracle Database Free.

### Swingbench Performance Summary

| Metric | Value |
|--------|-------|
| Average TPS | 1466.2 |
| Completed Transactions | 1,319,532 |
| iostat Samples | 1499 |
| OCI Metrics Entries | 1120 |

### Swingbench Cross-Layer Correlation

Correlation between guest iostat measurements and OCI Block Volume metrics during database workload.

| Metric | iostat vs OCI |
|--------|---------------|
| Pearson r | 0.766 |
| Pearson p-value | 0.0003 |
| Spearman ρ | 0.264 |
| Spearman p-value | 0.3066 |
| Aligned Samples | 35 |

### Swingbench iostat vs OCI Block Volumes

### iostat vs OCI Block Volumes

| Volume | Pearson r | p-value | iostat (MB/s) | OCI (MB/s) | Match |
|--------|-----------|---------|---------------|------------|-------|
| boot | 0.766 | 0.0003 | 83.2 | 4.5 | Strong |
| redo1 | 0.717 | 0.0012 | 83.2 | 234.0 | Strong |
| data2 | 0.703 | 0.0016 | 83.2 | 130.4 | Strong |
| data1 | 0.656 | 0.0042 | 83.2 | 129.7 | Moderate |
| fra | 0.628 | 0.0069 | 83.2 | 1.2 | Moderate |
| redo2 | 0.564 | 0.0183 | 83.2 | 232.3 | Moderate |

**Best match:** `boot` (r = 0.766)

**Boot volume correlation:** r = 0.766 (p = 0.0003)

### Per-Volume Type Correlation

Correlation between iostat per-volume metrics and matching OCI volumes:

| iostat Volume | OCI Volume | Pearson r | p-value | iostat (MB/s) | OCI (MB/s) |
|---------------|------------|-----------|---------|---------------|------------|
| boot | boot | 0.952 | 0.0000 | 0.2 | 4.5 |
| data | data1 | 0.580 | 0.0147 | 54.7 | 129.7 |
| data | data2 | 0.667 | 0.0035 | 54.7 | 130.4 |
| fra | fra | N/A | N/A | 0.0 | 1.2 |
| redo | redo1 | 0.895 | 0.0000 | 19.4 | 234.0 |
| redo | redo2 | 0.402 | 0.1101 | 19.4 | 232.3 |

### Lagged Per-Volume Correlation (Best Lag)

Best Pearson correlation over lag ±0..5 minutes for each iostat↔OCI matched pair.

| iostat Volume | OCI Volume | Best Lag (min) | Pearson r | p-value | N |
|---------------|------------|----------------|-----------|---------|---|
| boot | boot | 0 | 0.952 | 0.0000 | 17 |
| data | data1 | 1 | 0.654 | 0.0044 | 17 |
| data | data2 | 0 | 0.667 | 0.0035 | 17 |
| redo | redo1 | 0 | 0.895 | 0.0000 | 17 |
| redo | redo2 | -1 | -0.648 | 0.0067 | 16 |

### iostat vs Compute DiskBytesWritten
- Pearson r: 0.756 (p = 0.0005)
- iostat mean: 83.2 MB/s
- Compute DiskBytes mean: 29.6 MB/s

### Swingbench Full Correlation Matrix

Pearson correlations between all available metrics:

| Variable | io_boot_mbps | io_data_mbps | io_redo_mbps | oci_boot_mbps | oci_data_mbps | oci_redo_mbps | oci_fra_mbps | tps |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| io_boot_mbps | 1.00 | **0.97** | **0.90** | **0.95** | 0.30 | **0.93** | 0.14 | **-0.86** |
| io_data_mbps | **0.97** | 1.00 | **0.95** | **0.93** | 0.43 | **0.92** | 0.25 | **-0.77** |
| io_redo_mbps | **0.90** | **0.95** | 1.00 | **0.91** | *0.56* | **0.93** | *0.52* | **-0.72** |
| oci_boot_mbps | **0.95** | **0.93** | **0.91** | 1.00 | 0.33 | *0.64* | 0.10 | **-0.77** |
| oci_data_mbps | 0.30 | 0.43 | *0.56* | 0.33 | 1.00 | 0.49 | 0.31 | -0.22 |
| oci_redo_mbps | **0.93** | **0.92** | **0.93** | *0.64* | 0.49 | 1.00 | 0.07 | **-0.85** |
| oci_fra_mbps | 0.14 | 0.25 | *0.52* | 0.10 | 0.31 | 0.07 | 1.00 | 0.06 |
| tps | **-0.86** | **-0.77** | **-0.72** | **-0.77** | -0.22 | **-0.85** | 0.06 | 1.00 |

*Bold: |r| >= 0.7, Italic: |r| >= 0.5*

### Swingbench Significant Correlations

| Variable 1 | Variable 2 | Pearson r | p-value | Strength |
|------------|------------|-----------|---------|----------|
| io_boot_mbps | io_data_mbps | 0.969 | 0.0000 | strong |
| io_data_mbps | io_redo_mbps | 0.946 | 0.0000 | strong |
| io_boot_mbps | oci_boot_mbps | 0.946 | 0.0000 | strong |
| io_data_mbps | oci_boot_mbps | 0.933 | 0.0000 | strong |
| io_redo_mbps | oci_redo_mbps | 0.933 | 0.0000 | strong |
| io_boot_mbps | oci_redo_mbps | 0.930 | 0.0000 | strong |
| io_data_mbps | oci_redo_mbps | 0.918 | 0.0000 | strong |
| io_redo_mbps | oci_boot_mbps | 0.906 | 0.0000 | strong |
| io_boot_mbps | io_redo_mbps | 0.904 | 0.0000 | strong |
| io_boot_mbps | tps | -0.865 | 0.0000 | strong |

---

## Cross-Phase Comparison

Comparison of correlation strength between storage-level (FIO) and database-level (Swingbench) workloads.

| Metric | FIO Phase | Swingbench Phase | Interpretation |
|--------|-----------|------------------|----------------|
| Pearson r | 0.781 | 0.766 | FIO: strong, Swingbench: strong |
| Best Volume Match | redo2 (r=0.83) | boot (r=0.77) | Which volume shows highest correlation with iostat |
| Aligned Samples | 18 | 35 | - |

**Observations:**

- Both phases show moderate-to-strong correlation
- Cross-layer metrics are consistent across workload types

---

## Compute Resource Utilization

OCI Compute instance metrics during benchmark phases.

| Metric | FIO Phase | Swingbench Phase |
|--------|-----------|------------------|
| CpuUtilization | 7.9% | 6.6% |
| MemoryUtilization | 5.8% | 6.6% |
| DiskBytesRead | 407.5 MB/s | 0.0 MB/s |
| DiskBytesWritten | 209.5 MB/s | 29.6 MB/s |

---

## Anomalies and Findings

No anomalies detected in either phase.

---

## Conclusion

### Sprint 18 Evidence Quality Assessment

**Overall Verdict: PASS**

Both phases demonstrate acceptable evidence quality.

### Key Takeaways

- FIO phase validates cross-layer correlation (r=0.78)
- Swingbench achieved 1466 TPS average throughput
