"""Guest iostat data loader."""

import json
from pathlib import Path
from typing import Union
import pandas as pd
from datetime import datetime


def load_iostat_data(
    filepath: Union[str, Path],
    sprint: int = None,
    phase: str = None
) -> pd.DataFrame:
    """
    Load iostat JSON data into a DataFrame.

    Supports multiple formats:
    - sysstat JSON format (iostat -o JSON)
    - Custom dict format {"device": {"timestamp": {...}}}
    - List format [{"device": ..., ...}]

    Args:
        filepath: Path to *_iostat.json file
        sprint: Sprint number (optional)
        phase: 'fio' or 'swingbench' (optional, inferred from filename)

    Returns:
        DataFrame with columns:
        - sprint, phase, sample_idx, device
        - reads_per_sec, writes_per_sec
        - read_kbps, write_kbps
        - util_pct
    """
    filepath = Path(filepath)

    if sprint is None:
        for part in filepath.parts:
            if part.startswith('sprint_'):
                try:
                    sprint = int(part.split('_')[1])
                    break
                except (IndexError, ValueError):
                    pass

    if phase is None:
        fname = filepath.name.lower()
        if 'swingbench' in fname:
            phase = 'swingbench'
        elif 'fio' in fname:
            phase = 'fio'
        else:
            phase = 'unknown'

    with open(filepath, 'r') as f:
        data = json.load(f)

    rows = []

    # Check for sysstat JSON format
    if isinstance(data, dict) and 'sysstat' in data:
        rows = _parse_sysstat_format(data, sprint, phase)
    elif isinstance(data, dict):
        # Format: {"device": {"timestamp": {...metrics...}}}
        for device, samples in data.items():
            if not isinstance(samples, dict):
                continue
            for timestamp_str, metrics in samples.items():
                if not isinstance(metrics, dict):
                    continue
                try:
                    timestamp = pd.to_datetime(timestamp_str)
                except:
                    timestamp = None

                row = {
                    'sprint': sprint,
                    'phase': phase,
                    'timestamp': timestamp,
                    'device': device,
                    'reads_per_sec': float(metrics.get('r/s', 0)),
                    'writes_per_sec': float(metrics.get('w/s', 0)),
                    'read_kbps': float(metrics.get('rkB/s', 0)),
                    'write_kbps': float(metrics.get('wkB/s', 0)),
                    'util_pct': float(metrics.get('%util', 0)),
                }
                rows.append(row)

    elif isinstance(data, list):
        # Format: [{"device": ..., "timestamp": ..., ...}]
        for item in data:
            if not isinstance(item, dict):
                continue
            try:
                timestamp = pd.to_datetime(item.get('timestamp'))
            except:
                timestamp = None

            row = {
                'sprint': sprint,
                'phase': phase,
                'timestamp': timestamp,
                'device': item.get('device', 'unknown'),
                'reads_per_sec': float(item.get('r/s', 0)),
                'writes_per_sec': float(item.get('w/s', 0)),
                'read_kbps': float(item.get('rkB/s', 0)),
                'write_kbps': float(item.get('wkB/s', 0)),
                'util_pct': float(item.get('%util', 0)),
            }
            rows.append(row)

    df = pd.DataFrame(rows)

    if 'timestamp' in df.columns and not df['timestamp'].isna().all():
        df = df.sort_values('timestamp')
    elif 'sample_idx' in df.columns:
        df = df.sort_values('sample_idx')

    return df


def _parse_sysstat_format(data: dict, sprint: int, phase: str) -> list:
    """
    Parse sysstat JSON format (iostat -o JSON output).

    Structure:
    {
      "sysstat": {
        "hosts": [{
          "nodename": "...",
          "date": "MM/DD/YYYY",
          "statistics": [
            {"disk": [{"disk_device": "sda", "r/s": ..., ...}]},
            ...
          ]
        }]
      }
    }
    """
    rows = []

    sysstat = data.get('sysstat', {})
    hosts = sysstat.get('hosts', [])

    for host in hosts:
        date_str = host.get('date', '')
        statistics = host.get('statistics', [])

        for sample_idx, stat in enumerate(statistics):
            disks = stat.get('disk', [])

            for disk in disks:
                device = disk.get('disk_device', 'unknown')

                # Convert MB/s to KB/s if needed
                read_mbs = disk.get('rMB/s', 0)
                write_mbs = disk.get('wMB/s', 0)
                read_kbps = read_mbs * 1024 if read_mbs else disk.get('rkB/s', 0)
                write_kbps = write_mbs * 1024 if write_mbs else disk.get('wkB/s', 0)

                row = {
                    'sprint': sprint,
                    'phase': phase,
                    'sample_idx': sample_idx,
                    'device': device,
                    'reads_per_sec': float(disk.get('r/s', 0)),
                    'writes_per_sec': float(disk.get('w/s', 0)),
                    'read_kbps': float(read_kbps),
                    'write_kbps': float(write_kbps),
                    'util_pct': float(disk.get('util', disk.get('%util', 0))),
                }
                rows.append(row)

    return rows


def aggregate_iostat_by_device(df: pd.DataFrame) -> pd.DataFrame:
    """
    Aggregate iostat metrics by device.

    Returns:
        DataFrame with mean/max stats per device
    """
    if df.empty:
        return df

    agg = df.groupby('device').agg({
        'reads_per_sec': ['mean', 'max'],
        'writes_per_sec': ['mean', 'max'],
        'read_kbps': ['mean', 'max', 'sum'],
        'write_kbps': ['mean', 'max', 'sum'],
        'util_pct': ['mean', 'max'],
    })

    # Flatten column names
    agg.columns = ['_'.join(col).strip() for col in agg.columns.values]
    return agg.reset_index()
