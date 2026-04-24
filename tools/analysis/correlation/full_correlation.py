"""Full correlation matrix analysis across all variables."""

import pandas as pd
import numpy as np
from scipy import stats
from typing import Dict, List, Any, Tuple, Optional


def _safe_sum_cols(df: pd.DataFrame, cols: List[str]) -> Optional[pd.Series]:
    """Sum columns that exist; return None if none exist."""
    available = [c for c in cols if c in df.columns]
    if not available:
        return None
    return df[available].sum(axis=1, skipna=True)


def add_resource_mapped_columns(df: pd.DataFrame) -> pd.DataFrame:
    """
    Add normalized, topology-aware convenience columns.

    This does not remove any existing columns; it adds aliases/aggregates to make
    resource-based correlation easier and consistent across phases.

    Added columns (if source data exists):
    - iostat_<resource>_read_mbps / iostat_<resource>_write_mbps / iostat_<resource>_mbps
      where resource in {boot,data,redo,fra}
    - oci_<resource>_read_mbps / oci_<resource>_write_mbps / oci_<resource>_mbps
      where resource in {boot,data,redo,fra} and data/redo can be aggregated from multiple BVs
    """
    if df.empty:
        return df

    out = df.copy()

    # iostat per-volume-type columns are currently emitted as:
    #   boot_read_mbps, boot_write_mbps, data_read_mbps, ...
    for res in ['boot', 'data', 'redo', 'fra']:
        src_read = f'{res}_read_mbps'
        src_write = f'{res}_write_mbps'
        if src_read in out.columns:
            out[f'iostat_{res}_read_mbps'] = out[src_read]
        if src_write in out.columns:
            out[f'iostat_{res}_write_mbps'] = out[src_write]
        if src_read in out.columns or src_write in out.columns:
            out[f'iostat_{res}_mbps'] = out.get(src_read, 0) + out.get(src_write, 0)

    # OCI per-volume columns are emitted by pivot as "<resource>_<metric_name>"
    # e.g. data1_VolumeWriteThroughput, redo2_VolumeReadThroughput, boot_VolumeWriteThroughput
    def oci_cols_for(resource: str, metric_suffix: str) -> List[str]:
        if resource == 'data':
            prefixes = ['data', 'data1', 'data2']
        elif resource == 'redo':
            prefixes = ['redo', 'redo1', 'redo2']
        elif resource == 'fra':
            prefixes = ['fra']
        elif resource == 'boot':
            prefixes = ['boot']
        else:
            prefixes = [resource]
        cols = []
        for p in prefixes:
            cols.extend([c for c in out.columns if c.lower().startswith(f'{p}_'.lower()) and metric_suffix.lower() in c.lower()])
        # De-dupe while preserving order
        seen = set()
        deduped = []
        for c in cols:
            if c not in seen:
                seen.add(c)
                deduped.append(c)
        return deduped

    for res in ['boot', 'data', 'redo', 'fra']:
        read_cols = oci_cols_for(res, 'VolumeReadThroughput')
        write_cols = oci_cols_for(res, 'VolumeWriteThroughput')

        read_sum = _safe_sum_cols(out, read_cols)
        write_sum = _safe_sum_cols(out, write_cols)

        if read_sum is not None:
            out[f'oci_{res}_read_mbps'] = read_sum
        if write_sum is not None:
            out[f'oci_{res}_write_mbps'] = write_sum
        if read_sum is not None or write_sum is not None:
            out[f'oci_{res}_mbps'] = (read_sum if read_sum is not None else 0) + (write_sum if write_sum is not None else 0)

    return out


def compute_full_correlation_matrix(
    df: pd.DataFrame,
    include_patterns: List[str] = None,
    exclude_patterns: List[str] = None
) -> Dict[str, Any]:
    """
    Compute full Pearson correlation matrix for all numeric columns.

    Args:
        df: DataFrame with aligned metrics
        include_patterns: Only include columns matching these patterns
        exclude_patterns: Exclude columns matching these patterns

    Returns:
        Dict with:
        - 'matrix': Correlation matrix DataFrame
        - 'pvalues': P-value matrix DataFrame
        - 'significant_pairs': List of significantly correlated pairs
        - 'variable_groups': Grouped variable names
    """
    # Ensure resource-mapped convenience columns are present
    df = add_resource_mapped_columns(df)

    # Select numeric columns
    numeric_cols = df.select_dtypes(include=[np.number]).columns.tolist()

    # Default: restrict the full correlation matrix to TOP-LEVEL resource aggregates only.
    # (drill-down columns like data1_* / data2_* are intentionally excluded)
    if include_patterns is None:
        include_patterns = [
            # Top-level resource throughput (preferred)
            'iostat_boot_mbps', 'iostat_data_mbps', 'iostat_redo_mbps', 'iostat_fra_mbps',
            'oci_boot_mbps', 'oci_data_mbps', 'oci_redo_mbps', 'oci_fra_mbps',
            'fio_boot_mbps', 'fio_data_mbps', 'fio_redo_mbps', 'fio_fra_mbps',
            'tps',
        ]

    # Always exclude obvious non-topology signal columns unless explicitly requested.
    if exclude_patterns is None:
        exclude_patterns = []
    exclude_patterns = list(exclude_patterns) + [
        # raw iostat host aggregates (pre-aggregation)
        'read_kbps', 'write_kbps', 'reads_per_sec', 'writes_per_sec',
        # total iostat aggregates (not per-resource)
        'iostat_read_mbps', 'iostat_write_mbps',
        # drill-down / per-BV columns (we want top-level data/redo aggregation)
        'data1_', 'data2_', 'redo1_', 'redo2_',
        '_VolumeReadThroughput', '_VolumeWriteThroughput', '_VolumeReadOps', '_VolumeWriteOps',
        # compute metrics in correlation matrix (kept elsewhere in report)
        'CpuUtil', 'CpuUtilization', 'MemoryUtil', 'MemoryUtilization',
        'DiskBytes', 'DiskRead', 'DiskWritten', 'compute_',
    ]

    # Apply filters
    if include_patterns:
        # include_patterns here are treated as explicit column names (top-level)
        wanted = [p for p in include_patterns if p in df.columns]
        numeric_cols = [c for c in numeric_cols if c in wanted]

    if exclude_patterns:
        numeric_cols = [c for c in numeric_cols
                       if not any(p.lower() in c.lower() for p in exclude_patterns)]

    # Remove index-like columns
    numeric_cols = [c for c in numeric_cols if c not in ['sample_idx', 'index']]

    # Drop constant columns (avoid pearsonr warnings / meaningless correlations)
    if numeric_cols:
        non_constant = []
        for c in numeric_cols:
            s = df[c]
            if s.dropna().nunique() >= 2:
                non_constant.append(c)
        numeric_cols = non_constant

    if len(numeric_cols) < 2:
        return {
            'matrix': pd.DataFrame(),
            'pvalues': pd.DataFrame(),
            'significant_pairs': [],
            'variable_groups': {}
        }

    # Compute correlation matrix
    corr_matrix = df[numeric_cols].corr(method='pearson')

    # Pairwise observation counts (non-null overlaps)
    count_matrix = pd.DataFrame(
        np.zeros((len(numeric_cols), len(numeric_cols)), dtype=int),
        index=numeric_cols,
        columns=numeric_cols,
    )
    for i, col1 in enumerate(numeric_cols):
        for j, col2 in enumerate(numeric_cols):
            mask = df[[col1, col2]].notna().all(axis=1)
            count_matrix.loc[col1, col2] = int(mask.sum())

    # Compute p-values
    pvalue_matrix = pd.DataFrame(
        np.ones((len(numeric_cols), len(numeric_cols))),
        index=numeric_cols,
        columns=numeric_cols
    )

    for i, col1 in enumerate(numeric_cols):
        for j, col2 in enumerate(numeric_cols):
            if i < j:
                mask = df[[col1, col2]].notna().all(axis=1)
                if mask.sum() >= 3:
                    try:
                        _, pval = stats.pearsonr(
                            df.loc[mask, col1],
                            df.loc[mask, col2]
                        )
                        pvalue_matrix.loc[col1, col2] = pval
                        pvalue_matrix.loc[col2, col1] = pval
                    except:
                        pass

    # Find significant pairs (p < 0.05 and |r| > 0.3)
    # Guardrail: require a minimum number of overlapping points to avoid misleading |r|=1.00
    # on tiny sample sizes (common in short Sprint 17 Swingbench runs).
    min_pair_n = 10
    significant_pairs = []
    for i, col1 in enumerate(numeric_cols):
        for j, col2 in enumerate(numeric_cols):
            if i < j:
                r = corr_matrix.loc[col1, col2]
                p = pvalue_matrix.loc[col1, col2]
                n = int(count_matrix.loc[col1, col2]) if col1 in count_matrix.index and col2 in count_matrix.columns else 0
                # Guardrail: correlations with tiny overlap are not trustworthy.
                if n < min_pair_n:
                    continue
                if not np.isnan(r) and abs(r) > 0.3 and p < 0.05:
                    significant_pairs.append({
                        'var1': col1,
                        'var2': col2,
                        'r': r,
                        'p': p,
                        'n': n,
                        'strength': _interpret_r(r)
                    })

    # Sort by absolute correlation
    significant_pairs.sort(key=lambda x: abs(x['r']), reverse=True)

    # Group variables by type
    variable_groups = _group_variables(numeric_cols)

    return {
        'matrix': corr_matrix,
        'counts': count_matrix,
        'pvalues': pvalue_matrix,
        'significant_pairs': significant_pairs,
        'variable_groups': variable_groups,
        'columns': numeric_cols
    }


def compute_cross_layer_correlations(
    df: pd.DataFrame
) -> Dict[str, Any]:
    """
    Compute correlations specifically between observation layers:
    - Guest (iostat) - both total and per-volume (boot, data, redo, fra)
    - OCI Block Volumes (each volume separately)
    - OCI Compute
    - Workload (FIO/Swingbench)

    Returns summary of cross-layer correlations, including per-volume matching.
    """
    results = {
        'iostat_vs_volumes': [],
        'iostat_vs_compute': [],
        'best_volume_match': None,
        'boot_volume_correlation': None,
        'per_volume_match': {},  # matches iostat volume type with OCI volume
        'lagged_per_volume_match': {},  # best lag correlation per (iostat volume type ↔ OCI volume)
    }

    # Add normalized resource-mapped columns for downstream logic
    df = add_resource_mapped_columns(df)

    # Identify columns by layer
    iostat_write = 'iostat_write_mbps' if 'iostat_write_mbps' in df.columns else None
    iostat_read = 'iostat_read_mbps' if 'iostat_read_mbps' in df.columns else None

    # Find per-volume iostat columns (e.g., boot_write_mbps, data_write_mbps)
    per_volume_iostat = {}
    for vol_type in ['boot', 'data', 'redo', 'fra', 'other']:
        write_col = f'{vol_type}_write_mbps'
        read_col = f'{vol_type}_read_mbps'
        if write_col in df.columns:
            per_volume_iostat[vol_type] = {'write': write_col, 'read': read_col if read_col in df.columns else None}

    # Find all volume write throughput columns from OCI
    volume_cols = [c for c in df.columns if 'VolumeWriteThroughput' in c]

    # Correlate total iostat with each OCI volume (backward compatible)
    if iostat_write:
        for vol_col in volume_cols:
            mask = df[[iostat_write, vol_col]].notna().all(axis=1)
            if mask.sum() >= 3:
                try:
                    r, p = stats.pearsonr(
                        df.loc[mask, iostat_write],
                        df.loc[mask, vol_col]
                    )
                    vol_name = vol_col.split('_')[0]
                    results['iostat_vs_volumes'].append({
                        'volume': vol_name,
                        'column': vol_col,
                        'r': r,
                        'p': p,
                        'iostat_mean': df[iostat_write].mean(),
                        'volume_mean': df[vol_col].mean()
                    })

                    # Track boot volume specifically
                    if 'boot' in vol_col.lower():
                        results['boot_volume_correlation'] = {
                            'r': r,
                            'p': p,
                            'iostat_mean': df[iostat_write].mean(),
                            'boot_mean': df[vol_col].mean()
                        }
                except:
                    pass

        # Sort and find best match
        results['iostat_vs_volumes'].sort(key=lambda x: abs(x['r']) if not np.isnan(x['r']) else 0, reverse=True)
        if results['iostat_vs_volumes']:
            results['best_volume_match'] = results['iostat_vs_volumes'][0]

    # NEW: Per-volume matching - correlate iostat volume type with matching OCI volume type
    # e.g., boot_write_mbps vs boot_volume_VolumeWriteThroughput
    for vol_type, iostat_cols in per_volume_iostat.items():
        iostat_write_col = iostat_cols['write']
        if iostat_write_col not in df.columns:
            continue

        # Find matching OCI volume columns
        matching_oci_cols = [c for c in volume_cols if vol_type in c.lower() or
                            (vol_type == 'data' and any(x in c.lower() for x in ['data1', 'data2']))]

        for oci_col in matching_oci_cols:
            mask = df[[iostat_write_col, oci_col]].notna().all(axis=1)
            if mask.sum() >= 3:
                try:
                    r, p = stats.pearsonr(
                        df.loc[mask, iostat_write_col],
                        df.loc[mask, oci_col]
                    )
                    oci_vol_name = oci_col.split('_')[0]
                    match_key = f'{vol_type}_vs_{oci_vol_name}'
                    results['per_volume_match'][match_key] = {
                        'iostat_col': iostat_write_col,
                        'oci_col': oci_col,
                        'r': r,
                        'p': p,
                        'iostat_mean': df[iostat_write_col].mean(),
                        'oci_mean': df[oci_col].mean()
                    }
                except:
                    pass

        # Lagged correlation: best lag in +/- 5 minutes (minute buckets)
        # Choose best absolute Pearson r.
        lags = list(range(-5, 6))
        for oci_col in matching_oci_cols:
            best = {'best_lag_min': None, 'pearson_r': np.nan, 'pearson_p': np.nan, 'n': 0}
            for lag in lags:
                shifted = df[oci_col].shift(lag)
                mask = df[[iostat_write_col]].notna().all(axis=1) & shifted.notna()
                n = int(mask.sum())
                if n < 3:
                    continue
                try:
                    r, p = stats.pearsonr(df.loc[mask, iostat_write_col], shifted.loc[mask])
                except Exception:
                    continue
                if pd.isna(r):
                    continue
                if best['best_lag_min'] is None or abs(r) > abs(best['pearson_r']):
                    best = {'best_lag_min': lag, 'pearson_r': r, 'pearson_p': p, 'n': n}

            if best['best_lag_min'] is not None:
                oci_vol_name = oci_col.split('_')[0]
                match_key = f'{vol_type}_vs_{oci_vol_name}'
                results['lagged_per_volume_match'][match_key] = {
                    'iostat_col': iostat_write_col,
                    'oci_col': oci_col,
                    'best_lag_min': best['best_lag_min'],
                    'pearson_r': best['pearson_r'],
                    'pearson_p': best['pearson_p'],
                    'n_observations': best['n'],
                    'iostat_mean': df[iostat_write_col].mean(),
                    'oci_mean': df[oci_col].mean(),
                }

    # Correlate iostat with compute DiskBytes
    compute_disk = 'compute_DiskBytesWritten' if 'compute_DiskBytesWritten' in df.columns else None
    if iostat_write and compute_disk:
        mask = df[[iostat_write, compute_disk]].notna().all(axis=1)
        if mask.sum() >= 3:
            try:
                r, p = stats.pearsonr(
                    df.loc[mask, iostat_write],
                    df.loc[mask, compute_disk]
                )
                results['iostat_vs_compute'] = {
                    'r': r,
                    'p': p,
                    'iostat_mean': df[iostat_write].mean(),
                    'compute_mean': df[compute_disk].mean()
                }
            except:
                pass

    return results


def format_correlation_matrix_md(
    corr_result: Dict[str, Any],
    max_cols: int = 8
) -> str:
    """Format correlation matrix as Markdown table."""
    matrix = corr_result.get('matrix', pd.DataFrame())
    counts = corr_result.get('counts', pd.DataFrame())

    if matrix.empty:
        return "*No correlation data available.*\n"

    lines = []

    # Shorten column names for display
    short_names = {c: _shorten_name(c) for c in matrix.columns}

    # If too many columns, show only key ones (mix of iostat per-volume + OCI volumes)
    if len(matrix.columns) > max_cols:
        # Select a balanced mix: per-volume iostat write + matching OCI volume
        key_cols = []

        # First priority: per-volume iostat write columns
        iostat_vol_cols = [c for c in matrix.columns if any(
            c.startswith(f'{v}_write') for v in ['boot', 'data', 'redo', 'fra']
        )]
        key_cols.extend(iostat_vol_cols[:4])  # Max 4 iostat per-volume

        # Second priority: OCI volume Write throughput
        oci_vol_cols = [c for c in matrix.columns if 'VolumeWriteThroughput' in c]
        remaining = max_cols - len(key_cols)
        key_cols.extend(oci_vol_cols[:remaining])

        # Fill remaining with compute metrics
        if len(key_cols) < max_cols:
            compute_cols = [c for c in matrix.columns if 'compute_' in c or 'Cpu' in c or 'Disk' in c]
            remaining = max_cols - len(key_cols)
            for c in compute_cols:
                if c not in key_cols:
                    key_cols.append(c)
                    if len(key_cols) >= max_cols:
                        break

        # Fallback to any columns if we don't have enough
        if len(key_cols) < max_cols:
            for c in matrix.columns:
                if c not in key_cols:
                    key_cols.append(c)
                    if len(key_cols) >= max_cols:
                        break

        if key_cols:
            matrix = matrix.loc[key_cols, key_cols]
            short_names = {c: _shorten_name(c) for c in matrix.columns}

    # Header
    header = "| Variable |"
    for col in matrix.columns:
        header += f" {short_names[col]} |"
    lines.append(header)

    # Separator
    sep = "| --- |"
    for _ in matrix.columns:
        sep += " --- |"
    lines.append(sep)

    # Rows
    for idx in matrix.index:
        row = f"| {short_names[idx]} |"
        for col in matrix.columns:
            val = matrix.loc[idx, col]
            if pd.isna(val):
                row += " - |"
            elif idx == col:
                row += " 1.00 |"
            else:
                # Highlight strong correlations
                if abs(val) >= 0.7:
                    row += f" **{val:.2f}** |"
                elif abs(val) >= 0.5:
                    row += f" *{val:.2f}* |"
                else:
                    row += f" {val:.2f} |"
        lines.append(row)

    lines.append("")
    lines.append("*Bold: |r| >= 0.7, Italic: |r| >= 0.5*")
    # Low-N warning (important for Sprint 17 Swingbench TPS)
    min_warn_n = 10
    if isinstance(counts, pd.DataFrame) and not counts.empty:
        try:
            sub_counts = counts.reindex(index=matrix.index, columns=matrix.columns)
            # consider only off-diagonal pairs
            off = sub_counts.where(~np.eye(len(sub_counts), dtype=bool))
            arr = off.to_numpy(dtype=float)
            # Ignore zeros (no overlap) and NaNs when computing minimum positive n
            arr = arr[np.isfinite(arr) & (arr > 0)]
            min_n = int(arr.min()) if arr.size else 0
            if min_n and min_n < min_warn_n:
                lines.append("")
                lines.append(f"**Warning:** some correlations are computed on a small overlap (min n = {min_n}). Values based on n < {min_warn_n} are not statistically meaningful (small-n can yield |r| close to 1.00).")
        except Exception:
            pass
    lines.append("")

    return "\n".join(lines)


def format_significant_pairs_md(corr_result: Dict[str, Any], top_n: int = 10) -> str:
    """Format significant correlation pairs as Markdown."""
    pairs = corr_result.get('significant_pairs', [])[:top_n]

    if not pairs:
        return "*No significant correlations found (|r| > 0.3, p < 0.05, n >= 10).*\n"

    lines = [
        "| Variable 1 | Variable 2 | Pearson r | p-value | n | Strength |",
        "|------------|------------|-----------|---------|---:|----------|"
    ]

    for p in pairs:
        lines.append(
            f"| {_shorten_name(p['var1'])} | {_shorten_name(p['var2'])} | "
            f"{p['r']:.3f} | {p['p']:.4f} | {int(p.get('n', 0))} | {p['strength']} |"
        )

    lines.append("")
    return "\n".join(lines)


def format_cross_layer_md(cross_layer: Dict[str, Any]) -> str:
    """Format cross-layer correlation summary as Markdown."""
    lines = ["### iostat vs OCI Block Volumes", ""]

    vol_corrs = cross_layer.get('iostat_vs_volumes', [])
    if vol_corrs:
        lines.extend([
            "| Volume | Pearson r | p-value | iostat (MB/s) | OCI (MB/s) | Match |",
            "|--------|-----------|---------|---------------|------------|-------|"
        ])
        for v in vol_corrs:
            r = v['r']
            match = "Strong" if abs(r) >= 0.7 else "Moderate" if abs(r) >= 0.5 else "Weak" if abs(r) >= 0.3 else "None"
            r_str = f"{r:.3f}" if not np.isnan(r) else "N/A"
            p_str = f"{v['p']:.4f}" if not np.isnan(v['p']) else "N/A"
            lines.append(
                f"| {v['volume']} | {r_str} | {p_str} | "
                f"{v['iostat_mean']:.1f} | {v['volume_mean']:.1f} | {match} |"
            )
        lines.append("")

    best = cross_layer.get('best_volume_match')
    if best:
        lines.append(f"**Best match:** `{best['volume']}` (r = {best['r']:.3f})")
        lines.append("")

    boot = cross_layer.get('boot_volume_correlation')
    if boot:
        lines.append(f"**Boot volume correlation:** r = {boot['r']:.3f} (p = {boot['p']:.4f})")
        lines.append("")

    # Per-volume matching (iostat volume type vs OCI volume)
    per_vol = cross_layer.get('per_volume_match', {})
    if per_vol:
        lines.append("### Per-Volume Type Correlation")
        lines.append("")
        lines.append("Correlation between iostat per-volume metrics and matching OCI volumes:")
        lines.append("")
        lines.extend([
            "| iostat Volume | OCI Volume | Pearson r | p-value | iostat (MB/s) | OCI (MB/s) |",
            "|---------------|------------|-----------|---------|---------------|------------|"
        ])
        for match_key, v in sorted(per_vol.items()):
            r = v['r']
            r_str = f"{r:.3f}" if not np.isnan(r) else "N/A"
            p_str = f"{v['p']:.4f}" if not np.isnan(v['p']) else "N/A"
            iostat_vol = v['iostat_col'].replace('_write_mbps', '').replace('_read_mbps', '')
            oci_vol = v['oci_col'].split('_')[0]
            lines.append(
                f"| {iostat_vol} | {oci_vol} | {r_str} | {p_str} | "
                f"{v['iostat_mean']:.1f} | {v['oci_mean']:.1f} |"
            )
        lines.append("")

    lagged = cross_layer.get('lagged_per_volume_match', {})
    if lagged:
        lines.append("### Lagged Per-Volume Correlation (Best Lag)")
        lines.append("")
        lines.append("Best Pearson correlation over lag ±0..5 minutes for each iostat↔OCI matched pair.")
        lines.append("")
        lines.extend([
            "| iostat Volume | OCI Volume | Best Lag (min) | Pearson r | p-value | N |",
            "|---------------|------------|----------------|-----------|---------|---|"
        ])
        for match_key, v in sorted(lagged.items()):
            r = v.get('pearson_r', np.nan)
            p = v.get('pearson_p', np.nan)
            n = v.get('n_observations', 0)
            lag = v.get('best_lag_min', None)
            iostat_vol = v.get('iostat_col', '').replace('_write_mbps', '').replace('_read_mbps', '')
            oci_vol = v.get('oci_col', '').split('_')[0]
            r_str = f"{r:.3f}" if not np.isnan(r) else "N/A"
            p_str = f"{p:.4f}" if not np.isnan(p) else "N/A"
            lag_str = str(lag) if lag is not None else "N/A"
            lines.append(f"| {iostat_vol} | {oci_vol} | {lag_str} | {r_str} | {p_str} | {n} |")
        lines.append("")

    compute = cross_layer.get('iostat_vs_compute')
    if compute:
        lines.append("### iostat vs Compute DiskBytesWritten")
        lines.append(f"- Pearson r: {compute['r']:.3f} (p = {compute['p']:.4f})")
        lines.append(f"- iostat mean: {compute['iostat_mean']:.1f} MB/s")
        lines.append(f"- Compute DiskBytes mean: {compute['compute_mean']:.1f} MB/s")
        lines.append("")

    return "\n".join(lines)


def _shorten_name(name: str) -> str:
    """Shorten variable name for display."""
    replacements = [
        ('VolumeWriteThroughput', 'Write'),
        ('VolumeReadThroughput', 'Read'),
        ('VolumeWriteOps', 'WrOps'),
        ('VolumeReadOps', 'RdOps'),
        ('compute_', ''),
        ('primary_vnic_', 'vnic_'),
        ('iostat_', 'io_'),
        ('Utilization', 'Util'),
        ('DiskBytes', 'Disk'),
        ('_write_mbps', '_wr'),
        ('_read_mbps', '_rd'),
        ('_writes_per_sec', '_wps'),
        ('_reads_per_sec', '_rps'),
        ('boot_volume_', 'boot_'),
    ]
    result = name
    for old, new in replacements:
        result = result.replace(old, new)
    return result[:20]  # Max 20 chars


def _interpret_r(r: float) -> str:
    """Interpret correlation coefficient."""
    if np.isnan(r):
        return "undefined"
    ar = abs(r)
    if ar >= 0.7:
        return "strong"
    elif ar >= 0.5:
        return "moderate"
    elif ar >= 0.3:
        return "weak"
    else:
        return "negligible"


def _group_variables(columns: List[str]) -> Dict[str, List[str]]:
    """Group variables by type."""
    groups = {
        'guest_iostat': [],
        'oci_blockvolume': [],
        'oci_compute': [],
        'oci_network': [],
        'workload': [],
        'other': []
    }

    for col in columns:
        cl = col.lower()
        if 'iostat' in cl or cl in ['read_kbps', 'write_kbps', 'reads_per_sec', 'writes_per_sec']:
            groups['guest_iostat'].append(col)
        elif 'volume' in cl or any(x in cl for x in ['data1', 'data2', 'redo', 'fra', 'boot']):
            groups['oci_blockvolume'].append(col)
        elif 'compute' in cl or 'cpu' in cl or 'memory' in cl:
            groups['oci_compute'].append(col)
        elif 'vnic' in cl or 'network' in cl:
            groups['oci_network'].append(col)
        elif 'tps' in cl or 'fio' in cl or 'swingbench' in cl:
            groups['workload'].append(col)
        else:
            groups['other'].append(col)

    return {k: v for k, v in groups.items() if v}
