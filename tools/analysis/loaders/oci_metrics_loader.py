"""OCI Monitoring metrics loader."""

import json
from pathlib import Path
from typing import Union, List
import pandas as pd


def load_oci_metrics(
    filepath: Union[str, Path],
    sprint: int = None,
    phase: str = None
) -> pd.DataFrame:
    """
    Load OCI Monitoring metrics JSON into a DataFrame.

    Args:
        filepath: Path to *_oci_metrics_raw.json file
        sprint: Sprint number (optional)
        phase: 'fio' or 'swingbench' (optional)

    Returns:
        DataFrame with columns:
        - sprint, phase, timestamp
        - resource_name, resource_class, metric_name
        - value, value_scaled, unit
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

    for metric_entry in data:
        resource_name = metric_entry.get('resource_name', 'unknown')
        resource_class = metric_entry.get('class', 'unknown')
        metric_name = metric_entry.get('metric_name', 'unknown')
        scale = metric_entry.get('scale', 1)
        unit = metric_entry.get('unit', '')

        payload = metric_entry.get('payload', {})
        data_list = payload.get('data', [])

        for data_item in data_list:
            datapoints = data_item.get('aggregated-datapoints', [])

            for dp in datapoints:
                timestamp_str = dp.get('timestamp')
                value = dp.get('value', 0)

                try:
                    timestamp = pd.to_datetime(timestamp_str)
                except:
                    timestamp = None

                row = {
                    'sprint': sprint,
                    'phase': phase,
                    'timestamp': timestamp,
                    'resource_name': resource_name,
                    'resource_class': resource_class,
                    'metric_name': metric_name,
                    'value': value,
                    'value_scaled': value / scale if scale else value,
                    'unit': unit,
                }
                rows.append(row)

    df = pd.DataFrame(rows)

    if 'timestamp' in df.columns:
        df = df.sort_values('timestamp')

    return df


def pivot_oci_metrics(
    df: pd.DataFrame,
    resource_filter: List[str] = None
) -> pd.DataFrame:
    """
    Pivot OCI metrics to wide format for correlation analysis.

    Args:
        df: OCI metrics DataFrame
        resource_filter: List of resource names to include

    Returns:
        DataFrame with timestamp index and metric columns like:
        data1_VolumeReadThroughput, data1_VolumeWriteThroughput, etc.
    """
    if df.empty:
        return df

    if resource_filter:
        df = df[df['resource_name'].isin(resource_filter)]

    # Create column names
    df = df.copy()
    df['col_name'] = df['resource_name'] + '_' + df['metric_name']

    pivot = df.pivot_table(
        index='timestamp',
        columns='col_name',
        values='value_scaled',
        aggfunc='mean'
    )

    return pivot.reset_index()


def summarize_oci_metrics(df: pd.DataFrame) -> pd.DataFrame:
    """
    Summarize OCI metrics by resource and metric.

    Returns:
        DataFrame with mean/max/sum stats per resource-metric pair
    """
    if df.empty:
        return df

    agg = df.groupby(['resource_name', 'metric_name']).agg({
        'value_scaled': ['mean', 'max', 'sum', 'count'],
    })

    agg.columns = ['mean', 'max', 'sum', 'count']
    return agg.reset_index()
