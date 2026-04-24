"""Correlation analysis engine."""

from .time_alignment import align_timeseries
from .correlation_engine import (
    compute_pearson_matrix,
    compute_spearman_matrix,
    compute_quadrant_matrix,
)
from .anomaly_detector import AnomalyDetector, AnomalyRule
from .full_correlation import (
    compute_full_correlation_matrix,
    compute_cross_layer_correlations,
    format_correlation_matrix_md,
    format_significant_pairs_md,
    format_cross_layer_md,
)

__all__ = [
    'align_timeseries',
    'compute_pearson_matrix',
    'compute_spearman_matrix',
    'compute_quadrant_matrix',
    'AnomalyDetector',
    'AnomalyRule',
    'compute_full_correlation_matrix',
    'compute_cross_layer_correlations',
    'format_correlation_matrix_md',
    'format_significant_pairs_md',
    'format_cross_layer_md',
]
