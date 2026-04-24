"""FIO benchmark results loader."""

import json
from pathlib import Path
from typing import Union
import pandas as pd


def load_fio_results(filepath: Union[str, Path], sprint: int = None) -> pd.DataFrame:
    """
    Load FIO JSON results into a DataFrame.

    Args:
        filepath: Path to fio_results.json or similar
        sprint: Sprint number (optional, inferred from path if not provided)

    Returns:
        DataFrame with columns:
        - sprint, phase, job_name
        - read_bw_kbps, write_bw_kbps
        - read_iops, write_iops
        - read_lat_mean_us, write_lat_mean_us
        - read_lat_p99_us, write_lat_p99_us
        - runtime_s
    """
    filepath = Path(filepath)

    if sprint is None:
        # Try to extract sprint number from path
        for part in filepath.parts:
            if part.startswith('sprint_'):
                try:
                    sprint = int(part.split('_')[1])
                    break
                except (IndexError, ValueError):
                    pass

    with open(filepath, 'r') as f:
        data = json.load(f)

    rows = []
    jobs = data.get('jobs', [])

    for job in jobs:
        job_name = job.get('jobname', 'unknown')

        # Skip global options job if present
        if job_name in ['global', 'All clients']:
            continue

        read_stats = job.get('read', {})
        write_stats = job.get('write', {})

        # Extract latency percentiles
        read_clat = read_stats.get('clat_ns', {}).get('percentile', {})
        write_clat = write_stats.get('clat_ns', {}).get('percentile', {})

        row = {
            'sprint': sprint,
            'phase': 'fio',
            'job_name': job_name,
            'read_bw_kbps': read_stats.get('bw', 0),
            'write_bw_kbps': write_stats.get('bw', 0),
            'read_iops': read_stats.get('iops', 0),
            'write_iops': write_stats.get('iops', 0),
            'read_lat_mean_us': read_stats.get('lat_ns', {}).get('mean', 0) / 1000,
            'write_lat_mean_us': write_stats.get('lat_ns', {}).get('mean', 0) / 1000,
            'read_lat_p99_us': read_clat.get('99.000000', 0) / 1000,
            'write_lat_p99_us': write_clat.get('99.000000', 0) / 1000,
            'runtime_s': job.get('job_runtime', 0) / 1000,
        }
        rows.append(row)

    return pd.DataFrame(rows)


def load_fio_disk_util(filepath: Union[str, Path]) -> pd.DataFrame:
    """
    Load FIO disk utilization data.

    Returns:
        DataFrame with per-device disk stats
    """
    filepath = Path(filepath)

    with open(filepath, 'r') as f:
        data = json.load(f)

    rows = []
    disk_util = data.get('disk_util', [])

    for disk in disk_util:
        row = {
            'device': disk.get('name', 'unknown'),
            'read_ios': disk.get('read_ios', 0),
            'write_ios': disk.get('write_ios', 0),
            'read_ticks': disk.get('read_ticks', 0),
            'write_ticks': disk.get('write_ticks', 0),
            'util_pct': disk.get('util', 0),
        }
        rows.append(row)

    return pd.DataFrame(rows)
