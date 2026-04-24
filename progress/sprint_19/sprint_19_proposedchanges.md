# Proposed changes to analysis / design

## Analysis

1. Clearly enumerate test windows time frames and preparation time slots.

**Status: ADOPTED** - Will add test window enumeration table to analysis.

2. Statistical correlation - apply Quadrat Correlation Matrix next to Pearson/Spearman coefficients between observation layers
Visualization - Quadrat Correlation Matrix

**Status: ADOPTED** - Will add Quadrant Correlation Matrix for categorical/binned analysis alongside continuous correlations.

3. Generate markdown, and html reports.

**Status: ADOPTED** - Already planned; will ensure both MD and HTML outputs.

4. Correlation variables should be **topology-aware (per resource/device)** instead of mixing generic host-level variables (`read_kbps`, `io_read_mbps`, `DiskRead`, etc.) in a single matrix.

Proposed standardized per-resource variables (examples):
- iostat: `iostat_boot_mbps`, `iostat_data_mbps`, `iostat_redo_mbps`, `iostat_fra_mbps`
- OCI: `oci_boot_mbps`, `oci_data1_mbps`, `oci_data2_mbps`, `oci_redo1_mbps`, `oci_redo2_mbps`, `oci_fra_mbps`
- FIO (FIO phase only): `fio_data_mbps`, `fio_redo_mbps`, `fio_fra_mbps` (and optionally read/write split)
- Swingbench (Swingbench phase only): `swing_tps_total`, `swing_tps_<tx_name>` (optional)

**Status: PROPOSED** - Adopt “resource-mapped” schema and compute correlations per resource class (boot/data/redo/fra) and per phase (FIO vs Swingbench).

5. Add **lagged and rolling correlation** when correlating iostat ↔ OCI (OCI is 1-minute aggregated and may be time-shifted).

Proposed:
- Compute correlations for lag \(\pm\) 0..5 minutes and report best lag + best r.
- Optional rolling window (e.g. 5-min) for bursty DB workloads.

**Status: PROPOSED** - Improves robustness and reduces false “no correlation” conclusions caused by timestamp skew/aggregation.

6. Evidence quality time coverage should be computed from the **actual window length** and `freq`, not a fixed constant (e.g. `expected_points = 15`).

**Status: PROPOSED** - Derive expected points from window duration (start/end) and sampling frequency.

## Design

1. update to align with above.

**Status: ADOPTED** - Updating design document now.

2. Split correlation outputs into **phase-specific** sections (FIO phase vs Swingbench phase) and avoid putting FIO and Swingbench variables into the same correlation matrix.

**Status: PROPOSED** - Prevents mixing controlled storage benchmark signals with buffered DB workload behavior.

3. Update correlation matrix variable selection rules to avoid **redundant duplicates** (e.g., `read_kbps` and `io_read_mbps` are the same concept in different units).

**Status: PROPOSED** - Keep one metric per concept; normalize units (MB/s) across layers.

## Implementation

1. Update report generator to emit **per-resource correlation tables** (boot/data/redo/fra) and a summary “best match” per resource.

**Status: PROPOSED** - Makes topology defects obvious (e.g., boot hot while data volumes idle).

2. Update scoring/anomaly rules to operate on per-resource signals and to incorporate lagged correlation in the “cross-layer correlation” component.

**Status: PROPOSED** - Aligns scoring with the improved correlation model.
