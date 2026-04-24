"""Device to volume mapping for iostat data."""

import json
from pathlib import Path
from typing import Dict, List, Optional
import re


# Default volume type patterns
# Device names that match these patterns are classified into volume types
DEFAULT_VOLUME_PATTERNS = {
    'boot': [r'^sda$', r'^vda$', r'^nvme0n1$'],
    'data': [r'^sd[bcde]$', r'^vd[bcde]$', r'^nvme[1-4]n1$', r'^dm-[234]$', r'data'],
    'redo': [r'^sd[fg]$', r'^vd[fg]$', r'^dm-[56]$', r'redo'],
    'fra': [r'^sd[hi]$', r'^vd[hi]$', r'^dm-[78]$', r'fra'],
}


def load_device_mapping(sprint_dir: Path) -> Dict[str, str]:
    """
    Load device to volume mapping from state files or config.

    Args:
        sprint_dir: Sprint directory containing state files

    Returns:
        Dict mapping device name to volume type (e.g., {'sdb': 'data1', 'sdc': 'data2'})
    """
    mapping = {}

    # Try to load from explicit mapping file first
    mapping_file = sprint_dir / 'device_mapping.json'
    if mapping_file.exists():
        with open(mapping_file) as f:
            return json.load(f)

    # Try to infer from state files
    state_files = list(sprint_dir.glob('state-bv-*.json'))
    for state_file in state_files:
        try:
            with open(state_file) as f:
                state = json.load(f)

            # Extract volume name from filename (e.g., state-bv-data1.json -> data1)
            match = re.search(r'state-bv-(\w+)', state_file.name)
            if not match:
                continue
            volume_name = match.group(1)

            # Get device path from state
            device_path = state.get('blockvolume', {}).get('device_path', '')
            if not device_path:
                device_path = state.get('inputs', {}).get('bv_device_path', '')

            if device_path:
                # Extract device name from path (e.g., /dev/oracleoci/oraclevdb -> vdb)
                device_name = Path(device_path).name
                # Map to simple device letter if OCI format
                if device_name.startswith('oraclevd'):
                    letter = device_name[-1]  # oraclevdb -> b
                    mapping[f'sd{letter}'] = volume_name
                    mapping[device_name] = volume_name
                else:
                    mapping[device_name] = volume_name

        except (json.JSONDecodeError, KeyError):
            continue

    return mapping


def classify_device(device: str, explicit_mapping: Dict[str, str] = None) -> str:
    """
    Classify a device into a volume type.

    Args:
        device: Device name (e.g., 'sda', 'dm-0', 'sdb')
        explicit_mapping: Optional explicit device -> volume mapping

    Returns:
        Volume type (e.g., 'boot', 'data', 'redo', 'fra', 'other')
    """
    # Check explicit mapping first
    if explicit_mapping and device in explicit_mapping:
        vol = explicit_mapping[device]
        # Normalize to volume type
        if 'data' in vol.lower():
            return 'data'
        elif 'redo' in vol.lower():
            return 'redo'
        elif 'fra' in vol.lower():
            return 'fra'
        elif 'boot' in vol.lower():
            return 'boot'
        return vol

    # Use pattern matching
    for vol_type, patterns in DEFAULT_VOLUME_PATTERNS.items():
        for pattern in patterns:
            if re.match(pattern, device, re.IGNORECASE):
                return vol_type

    return 'other'


def aggregate_iostat_by_volume(
    iostat_df,
    device_mapping: Dict[str, str] = None,
    volume_types: List[str] = None
):
    """
    Aggregate iostat data by volume type.

    Args:
        iostat_df: DataFrame with iostat data (must have 'device' column)
        device_mapping: Optional explicit device -> volume mapping
        volume_types: Volume types to include (default: all)

    Returns:
        DataFrame with per-volume metrics aggregated by timestamp/sample
    """
    import pandas as pd

    if iostat_df.empty or 'device' not in iostat_df.columns:
        return iostat_df

    # Add volume_type column
    df = iostat_df.copy()
    df['volume_type'] = df['device'].apply(
        lambda d: classify_device(d, device_mapping)
    )

    # Filter volume types if specified
    if volume_types:
        df = df[df['volume_type'].isin(volume_types)]

    # Determine grouping column
    if 'timestamp' in df.columns and not df['timestamp'].isna().all():
        group_col = 'timestamp'
    elif 'sample_idx' in df.columns:
        group_col = 'sample_idx'
    else:
        # Add index as grouping
        df['_idx'] = range(len(df))
        group_col = '_idx'

    # Aggregate by volume type and time
    agg_cols = {
        'read_kbps': 'sum',
        'write_kbps': 'sum',
        'reads_per_sec': 'sum',
        'writes_per_sec': 'sum',
    }

    # Keep only columns that exist
    agg_cols = {k: v for k, v in agg_cols.items() if k in df.columns}

    if not agg_cols:
        return df

    # Pivot to get volume types as columns
    result_dfs = []

    # Get unique timestamps/samples
    for vol_type in df['volume_type'].unique():
        vol_df = df[df['volume_type'] == vol_type].copy()

        # Sum all devices of same volume type per timestamp
        vol_agg = vol_df.groupby(group_col).agg(agg_cols).reset_index()

        # Rename columns with volume type prefix
        rename_map = {col: f'{vol_type}_{col}' for col in agg_cols.keys()}
        vol_agg = vol_agg.rename(columns=rename_map)

        result_dfs.append(vol_agg)

    # Merge all volume types
    if not result_dfs:
        return pd.DataFrame()

    result = result_dfs[0]
    for other_df in result_dfs[1:]:
        result = result.merge(other_df, on=group_col, how='outer')

    # Fill NaN with 0 for missing volume types
    result = result.fillna(0)

    # Add total columns for backward compatibility
    read_cols = [c for c in result.columns if c.endswith('_read_kbps')]
    write_cols = [c for c in result.columns if c.endswith('_write_kbps')]

    if read_cols:
        result['total_read_kbps'] = result[read_cols].sum(axis=1)
    if write_cols:
        result['total_write_kbps'] = result[write_cols].sum(axis=1)

    return result


def create_volume_iostat_df(iostat_df, sprint_dir: Path = None):
    """
    Create a DataFrame with per-volume iostat metrics.

    Columns will be like:
    - boot_read_kbps, boot_write_kbps
    - data_read_kbps, data_write_kbps
    - redo_read_kbps, redo_write_kbps
    - fra_read_kbps, fra_write_kbps

    Args:
        iostat_df: Raw iostat DataFrame with 'device' column
        sprint_dir: Optional sprint directory for loading device mapping

    Returns:
        DataFrame with per-volume metrics
    """
    device_mapping = {}
    if sprint_dir:
        device_mapping = load_device_mapping(sprint_dir)

    return aggregate_iostat_by_volume(
        iostat_df,
        device_mapping=device_mapping,
        volume_types=['boot', 'data', 'redo', 'fra']
    )
