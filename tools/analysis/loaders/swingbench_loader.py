"""Swingbench benchmark results loader."""

import json
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Union
import pandas as pd


def load_swingbench_results(
    filepath: Union[str, Path],
    sprint: int = None
) -> dict:
    """
    Load Swingbench results from JSON or XML.

    Args:
        filepath: Path to swingbench_results_db.json or swingbench_results.xml
        sprint: Sprint number (optional)

    Returns:
        dict with 'summary', 'transactions', 'tps_readings' DataFrames
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

    if filepath.suffix == '.json':
        return _load_swingbench_json(filepath, sprint)
    elif filepath.suffix == '.xml':
        return _load_swingbench_xml(filepath, sprint)
    else:
        raise ValueError(f"Unsupported file format: {filepath.suffix}")


def _load_swingbench_json(filepath: Path, sprint: int) -> dict:
    """Load Swingbench JSON format."""
    with open(filepath, 'r') as f:
        data = json.load(f)

    # Handle nested Results structure from Swingbench XML-to-JSON
    if 'Results' in data:
        results = data['Results']
        overview = results.get('Overview', {})
        tx_results = results.get('TransactionResults', {})
        benchmark_metrics = results.get('BenchmarkMetrics', {})

        # Summary
        summary = pd.DataFrame([{
            'sprint': sprint,
            'benchmark_name': overview.get('BenchmarkName', '').strip('"'),
            'run_time': overview.get('TotalRunTime', ''),
            'completed_tx': int(overview.get('TotalCompletedTransactions', 0)),
            'failed_tx': int(overview.get('TotalFailedTransactions', 0)),
            'avg_tps': float(overview.get('AverageTransactionsPerSecond', 0)),
            'max_tps': float(overview.get('MaximumTransactionRate', 0)),
        }])

        # Transactions
        tx_list = tx_results.get('Result', [])
        if isinstance(tx_list, dict):
            tx_list = [tx_list]
        tx_rows = []
        for tx in tx_list:
            tx_rows.append({
                'sprint': sprint,
                'name': tx.get('id', ''),
                'count': int(tx.get('TransactionCount', 0)),
                'avg_response': float(tx.get('AverageResponse', 0)),
                'p90_response': float(tx.get('NinetiethPercentile', 0)),
            })
        transactions = pd.DataFrame(tx_rows)

        # TPS readings - parse "timestamp, tps, timestamp, tps, ..." format
        tps_str = benchmark_metrics.get('TPSReadings', '')
        tps_rows = []
        if tps_str:
            parts = tps_str.split(',')
            for i in range(0, len(parts) - 1, 2):
                try:
                    ts = int(parts[i].strip())
                    tps = int(parts[i + 1].strip())
                    tps_rows.append({
                        'sprint': sprint,
                        'timestamp': pd.to_datetime(ts, unit='ms'),
                        'tps': tps,
                    })
                except (ValueError, IndexError):
                    pass
        tps_readings = pd.DataFrame(tps_rows)

    else:
        # Legacy flat format
        summary = pd.DataFrame([{
            'sprint': sprint,
            'benchmark_name': data.get('benchmark_name', ''),
            'run_time': data.get('run_time', ''),
            'completed_tx': data.get('completed_transactions', 0),
            'failed_tx': data.get('failed_transactions', 0),
            'avg_tps': data.get('average_tps', 0),
            'max_tps': data.get('maximum_transaction_rate', 0),
        }])

        tx_data = data.get('transaction_results', [])
        transactions = pd.DataFrame(tx_data)
        if not transactions.empty:
            transactions['sprint'] = sprint

        tps_data = data.get('tps_readings', [])
        tps_readings = pd.DataFrame(tps_data)
        if not tps_readings.empty:
            tps_readings['sprint'] = sprint
            if 'timestamp' in tps_readings.columns:
                tps_readings['timestamp'] = pd.to_datetime(tps_readings['timestamp'])

    return {
        'summary': summary,
        'transactions': transactions,
        'tps_readings': tps_readings,
    }


def _load_swingbench_xml(filepath: Path, sprint: int) -> dict:
    """Load Swingbench XML format."""
    tree = ET.parse(filepath)
    root = tree.getroot()

    # Summary
    summary_data = {
        'sprint': sprint,
        'benchmark_name': _get_xml_text(root, './/BenchmarkName'),
        'run_time': _get_xml_text(root, './/RunTime'),
        'completed_tx': _get_xml_int(root, './/CompletedTransactions'),
        'failed_tx': _get_xml_int(root, './/FailedTransactions'),
        'avg_tps': _get_xml_float(root, './/AverageTPS'),
        'max_tps': _get_xml_float(root, './/MaximumTransactionRate'),
    }
    summary = pd.DataFrame([summary_data])

    # Transactions
    tx_rows = []
    for tx in root.findall('.//TransactionResult'):
        tx_rows.append({
            'sprint': sprint,
            'name': _get_xml_text(tx, 'Name'),
            'count': _get_xml_int(tx, 'TransactionCount'),
            'avg_response': _get_xml_float(tx, 'AverageResponse'),
            'min_response': _get_xml_float(tx, 'MinimumResponse'),
            'max_response': _get_xml_float(tx, 'MaximumResponse'),
            'p90_response': _get_xml_float(tx, 'NinetiethPercentile'),
        })
    transactions = pd.DataFrame(tx_rows)

    # TPS readings
    tps_rows = []
    for reading in root.findall('.//TPSReading'):
        timestamp = reading.get('timestamp') or _get_xml_text(reading, 'Timestamp')
        tps = reading.get('tps') or _get_xml_text(reading, 'TPS')
        tps_rows.append({
            'sprint': sprint,
            'timestamp': pd.to_datetime(timestamp) if timestamp else None,
            'tps': float(tps) if tps else 0,
        })
    tps_readings = pd.DataFrame(tps_rows)

    return {
        'summary': summary,
        'transactions': transactions,
        'tps_readings': tps_readings,
    }


def _get_xml_text(element, path: str) -> str:
    """Get text from XML element."""
    el = element.find(path)
    return el.text if el is not None and el.text else ''


def _get_xml_int(element, path: str) -> int:
    """Get integer from XML element."""
    text = _get_xml_text(element, path)
    try:
        return int(text)
    except (ValueError, TypeError):
        return 0


def _get_xml_float(element, path: str) -> float:
    """Get float from XML element."""
    text = _get_xml_text(element, path)
    try:
        return float(text)
    except (ValueError, TypeError):
        return 0.0


def get_swingbench_tps_series(results: dict) -> pd.DataFrame:
    """
    Extract TPS time-series for correlation analysis.

    Returns:
        DataFrame with timestamp and tps columns
    """
    return results.get('tps_readings', pd.DataFrame())
