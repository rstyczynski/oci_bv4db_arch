"""Time-series alignment for cross-layer correlation."""

import pandas as pd
import numpy as np
from typing import List, Optional


def align_timeseries(
    *dataframes: pd.DataFrame,
    time_col: str = 'timestamp',
    freq: str = '1min',
    method: str = 'mean'
) -> pd.DataFrame:
    """
    Align multiple time-series DataFrames to a common time index.

    Args:
        *dataframes: Variable number of DataFrames with timestamp column
        time_col: Name of timestamp column
        freq: Resampling frequency (e.g., '1min', '5min')
        method: Aggregation method ('mean', 'sum', 'max')

    Returns:
        Merged DataFrame aligned to common time index
    """
    aligned_dfs = []

    for i, df in enumerate(dataframes):
        if df.empty or time_col not in df.columns:
            continue

        df = df.copy()
        df[time_col] = pd.to_datetime(df[time_col])
        df = df.set_index(time_col)

        # Select only numeric columns
        numeric_cols = df.select_dtypes(include=[np.number]).columns.tolist()

        if not numeric_cols:
            continue

        # Resample
        if method == 'mean':
            resampled = df[numeric_cols].resample(freq).mean()
        elif method == 'sum':
            resampled = df[numeric_cols].resample(freq).sum()
        elif method == 'max':
            resampled = df[numeric_cols].resample(freq).max()
        else:
            resampled = df[numeric_cols].resample(freq).mean()

        aligned_dfs.append(resampled)

    if not aligned_dfs:
        return pd.DataFrame()

    # Merge all DataFrames
    result = aligned_dfs[0]
    for df in aligned_dfs[1:]:
        result = result.join(df, how='outer', rsuffix='_dup')

    # Remove duplicate columns
    result = result.loc[:, ~result.columns.str.endswith('_dup')]

    return result.reset_index()


def align_iostat_oci(
    iostat_df: pd.DataFrame,
    oci_df: pd.DataFrame,
    freq: str = '1min',
    sprint_dir=None,
    device_mapping: dict = None,
    sample_interval_sec: int = 10,
    reference_start_ts: Optional[pd.Timestamp] = None,
) -> pd.DataFrame:
    """
    Align iostat and OCI metrics specifically.

    Args:
        iostat_df: iostat DataFrame with timestamp or sample_idx
        oci_df: OCI metrics DataFrame (already pivoted)
        freq: Resampling frequency
        sprint_dir: Sprint directory for loading device mapping
        device_mapping: Explicit device to volume mapping

    Returns:
        Aligned DataFrame with iostat and OCI columns, including per-volume metrics
    """
    from pathlib import Path

    if iostat_df.empty or oci_df.empty:
        return pd.DataFrame()

    # Load device mapping if sprint_dir provided
    if sprint_dir and not device_mapping:
        try:
            from loaders.device_mapping import load_device_mapping, classify_device
            device_mapping = load_device_mapping(Path(sprint_dir))
        except ImportError:
            try:
                from ..loaders.device_mapping import load_device_mapping, classify_device
                device_mapping = load_device_mapping(Path(sprint_dir))
            except ImportError:
                device_mapping = {}

    # Aggregate iostat across all devices
    iostat_agg = iostat_df.copy()

    # Check if we have timestamps or sample indices
    has_timestamp = 'timestamp' in iostat_agg.columns and not iostat_agg['timestamp'].isna().all()
    has_sample_idx = 'sample_idx' in iostat_agg.columns

    # Classify devices into volume types
    if 'device' in iostat_agg.columns:
        try:
            from loaders.device_mapping import classify_device
        except ImportError:
            try:
                from ..loaders.device_mapping import classify_device
            except ImportError:
                classify_device = lambda d, m: 'other'
        iostat_agg['volume_type'] = iostat_agg['device'].apply(
            lambda d: classify_device(d, device_mapping)
        )

    # Sum across devices for total throughput
    numeric_cols = ['read_kbps', 'write_kbps', 'reads_per_sec', 'writes_per_sec']
    available_cols = [c for c in numeric_cols if c in iostat_agg.columns]

    # Determine grouping column
    if has_timestamp:
        iostat_agg['timestamp'] = pd.to_datetime(iostat_agg['timestamp'])
        group_col = 'timestamp'
    elif has_sample_idx:
        group_col = 'sample_idx'
    else:
        group_col = None

    # Aggregate by volume type
    volume_dfs = []
    if 'volume_type' in iostat_agg.columns and group_col:
        for vol_type in iostat_agg['volume_type'].unique():
            vol_df = iostat_agg[iostat_agg['volume_type'] == vol_type]
            if group_col == 'timestamp':
                # For rate-like metrics (KB/s, ops/s) we must NOT sum over time.
                # Correct approach:
                #   1) sum across devices at each timestamp (same-second)
                #   2) resample to 1-minute buckets using mean over time
                vol_df = vol_df.copy()
                vol_df['timestamp'] = pd.to_datetime(vol_df['timestamp'], errors='coerce')
                vol_df = vol_df.dropna(subset=['timestamp'])
                per_ts = vol_df.groupby('timestamp')[available_cols].sum()
                vol_agg = per_ts.resample(freq).mean().reset_index()
            else:
                vol_agg = vol_df.groupby(group_col)[available_cols].sum().reset_index()

            # Rename with volume type prefix and convert to MB/s
            for col in available_cols:
                if 'kbps' in col:
                    new_col = f'{vol_type}_{col.replace("kbps", "mbps")}'
                    vol_agg[new_col] = vol_agg[col] / 1024
                else:
                    vol_agg[f'{vol_type}_{col}'] = vol_agg[col]
            vol_agg = vol_agg.drop(columns=available_cols)
            volume_dfs.append(vol_agg)

    # Also compute total across all devices (for backward compatibility)
    if has_timestamp:
        # Same logic as above: sum across devices per timestamp, then mean over time buckets.
        iostat_total = iostat_agg.copy()
        iostat_total['timestamp'] = pd.to_datetime(iostat_total['timestamp'], errors='coerce')
        iostat_total = iostat_total.dropna(subset=['timestamp'])
        per_ts_total = iostat_total.groupby('timestamp')[available_cols].sum()
        iostat_resampled = per_ts_total.resample(freq).mean()
    elif has_sample_idx:
        iostat_resampled = iostat_agg.groupby('sample_idx')[available_cols].sum()
    else:
        iostat_resampled = iostat_agg[available_cols].sum().to_frame().T

    # Convert KB/s to MB/s for comparison with OCI
    if 'read_kbps' in iostat_resampled.columns:
        iostat_resampled['iostat_read_mbps'] = iostat_resampled['read_kbps'] / 1024
    if 'write_kbps' in iostat_resampled.columns:
        iostat_resampled['iostat_write_mbps'] = iostat_resampled['write_kbps'] / 1024

    # Prepare OCI data
    oci_aligned = oci_df.copy()
    if 'timestamp' in oci_aligned.columns:
        oci_aligned['timestamp'] = pd.to_datetime(oci_aligned['timestamp'])
        oci_aligned = oci_aligned.set_index('timestamp')

    # If iostat has sample_idx and OCI has timestamps, reconstruct timestamps for iostat
    if has_sample_idx and not has_timestamp:
        # OCI has timestamps, iostat has sample indices.
        # The harness collects iostat with a fixed interval (Sprint 17/18: 10s).
        # Reconstruct timestamps: t(i) = t0 + i * sample_interval_sec.
        # Prefer an explicit reference start timestamp (e.g., Swingbench TPS start).
        oci_ts = None
        if reference_start_ts is not None and not pd.isna(reference_start_ts):
            oci_ts = pd.to_datetime(reference_start_ts)
        else:
            try:
                oci_ts = oci_aligned.index.min()
            except Exception:
                oci_ts = None

        if oci_ts is None or pd.isna(oci_ts):
            # Fallback to previous behavior if OCI timestamps are missing
            oci_aligned = oci_aligned.reset_index()
            oci_aligned['sample_idx'] = range(len(oci_aligned))
            max_idx = min(len(iostat_resampled), len(oci_aligned))
            iostat_subset = iostat_resampled.head(max_idx).reset_index()
            oci_subset = oci_aligned.head(max_idx)
            result = pd.merge(iostat_subset, oci_subset, on='sample_idx', how='outer')
            for vol_df in volume_dfs:
                vol_subset = vol_df.head(max_idx)
                result = pd.merge(result, vol_subset, on='sample_idx', how='outer')
        else:
            # Build timestamp index for iostat totals
            iostat_ts = iostat_resampled.copy()
            iostat_ts = iostat_ts.reset_index()  # sample_idx column
            iostat_ts['timestamp'] = pd.to_datetime(oci_ts) + pd.to_timedelta(
                iostat_ts['sample_idx'].astype(int) * int(sample_interval_sec), unit='s'
            )
            iostat_ts = iostat_ts.set_index('timestamp')

            # Resample iostat to requested alignment frequency (rates => mean over time)
            iostat_ts = iostat_ts.drop(columns=['sample_idx']).resample(freq).mean()

            # Add per-volume iostat metrics similarly
            vol_join = []
            for vol_df in volume_dfs:
                v = vol_df.copy()
                if 'sample_idx' not in v.columns:
                    continue
                v['timestamp'] = pd.to_datetime(oci_ts) + pd.to_timedelta(
                    v['sample_idx'].astype(int) * int(sample_interval_sec), unit='s'
                )
                v = v.set_index('timestamp').drop(columns=['sample_idx']).resample(freq).mean()
                vol_join.append(v)

            # Join with OCI by timestamp.
            # If aligning at higher cadence than OCI (freq != 1min), expand OCI by forward-fill.
            if str(freq).lower() != '1min':
                oci_expanded = oci_aligned.copy()
                oci_expanded = oci_expanded.reindex(iostat_ts.index.union(oci_expanded.index)).sort_index().ffill()
                oci_expanded = oci_expanded.reindex(iostat_ts.index)
                result = iostat_ts.join(oci_expanded, how='outer')
            else:
                result = iostat_ts.join(oci_aligned, how='outer')
            for v in vol_join:
                result = result.join(v, how='outer')
            result = result.reset_index()

    elif has_timestamp:
        # Both have timestamps
        result = iostat_resampled.join(oci_aligned, how='outer')
        result = result.reset_index()

        # Add per-volume iostat metrics
        for vol_df in volume_dfs:
            vol_df = vol_df.set_index('timestamp')
            result = result.set_index('timestamp').join(vol_df, how='outer').reset_index()

    else:
        # Just concatenate
        result = pd.concat([iostat_resampled.reset_index(drop=True),
                           oci_aligned.reset_index(drop=True)], axis=1)
        # Add per-volume metrics
        for vol_df in volume_dfs:
            result = pd.concat([result, vol_df.reset_index(drop=True)], axis=1)

    return result


def compute_time_coverage(
    df: pd.DataFrame,
    start_time: pd.Timestamp,
    end_time: pd.Timestamp,
    time_col: str = 'timestamp'
) -> float:
    """
    Compute percentage of time window covered by data points.

    Args:
        df: DataFrame with timestamp
        start_time: Expected start of window
        end_time: Expected end of window
        time_col: Name of timestamp column

    Returns:
        Coverage percentage (0-100)
    """
    if df.empty or time_col not in df.columns:
        return 0.0

    expected_minutes = (end_time - start_time).total_seconds() / 60
    if expected_minutes <= 0:
        return 0.0

    # Count non-null data points in window
    df_window = df[
        (df[time_col] >= start_time) &
        (df[time_col] <= end_time)
    ]

    actual_points = len(df_window)
    expected_points = expected_minutes  # 1 point per minute

    return min(100.0, (actual_points / expected_points) * 100)
