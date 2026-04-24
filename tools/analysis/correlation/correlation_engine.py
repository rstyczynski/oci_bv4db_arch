"""Correlation computation engine."""

import pandas as pd
import numpy as np
from scipy import stats
from typing import Tuple, Dict, List, Optional


def compute_pearson_matrix(
    df: pd.DataFrame,
    columns: List[str] = None
) -> pd.DataFrame:
    """
    Compute Pearson correlation matrix.

    Args:
        df: DataFrame with numeric columns
        columns: Specific columns to correlate (optional)

    Returns:
        Correlation matrix DataFrame
    """
    if columns:
        available = [c for c in columns if c in df.columns]
        if not available:
            return pd.DataFrame()
        df = df[available]

    return df.select_dtypes(include=[np.number]).corr(method='pearson')


def compute_spearman_matrix(
    df: pd.DataFrame,
    columns: List[str] = None
) -> pd.DataFrame:
    """
    Compute Spearman rank correlation matrix.

    Args:
        df: DataFrame with numeric columns
        columns: Specific columns to correlate (optional)

    Returns:
        Correlation matrix DataFrame
    """
    if columns:
        available = [c for c in columns if c in df.columns]
        if not available:
            return pd.DataFrame()
        df = df[available]

    return df.select_dtypes(include=[np.number]).corr(method='spearman')


def compute_correlation_with_pvalue(
    df: pd.DataFrame,
    col1: str,
    col2: str,
    method: str = 'pearson'
) -> Tuple[float, float]:
    """
    Compute correlation with p-value.

    Args:
        df: DataFrame
        col1: First column name
        col2: Second column name
        method: 'pearson' or 'spearman'

    Returns:
        Tuple of (correlation, p-value)
    """
    if col1 not in df.columns or col2 not in df.columns:
        return (np.nan, np.nan)

    mask = df[[col1, col2]].notna().all(axis=1)
    if mask.sum() < 3:
        return (np.nan, np.nan)

    x = df.loc[mask, col1]
    y = df.loc[mask, col2]

    if method == 'pearson':
        return stats.pearsonr(x, y)
    else:
        return stats.spearmanr(x, y)


def compute_quadrant_matrix(
    df: pd.DataFrame,
    col1: str,
    col2: str,
    percentiles: Tuple[float, float] = (33, 66)
) -> Dict:
    """
    Compute quadrant correlation matrix for categorical analysis.

    Bins continuous values into Low/Medium/High categories and creates
    contingency table with Chi-squared test.

    Args:
        df: DataFrame
        col1: First column name
        col2: Second column name
        percentiles: Thresholds for Low/Medium/High (default 33/66)

    Returns:
        Dict with keys:
        - 'matrix': Contingency table DataFrame
        - 'chi2': Chi-squared statistic
        - 'p_value': P-value
        - 'dof': Degrees of freedom
        - 'agreement_pct': Diagonal agreement percentage
        - 'categories': Category labels
    """
    if col1 not in df.columns or col2 not in df.columns:
        return {
            'matrix': pd.DataFrame(),
            'chi2': np.nan,
            'p_value': np.nan,
            'dof': 0,
            'agreement_pct': 0,
            'categories': []
        }

    # Drop NaN rows
    df_clean = df[[col1, col2]].dropna()
    if len(df_clean) < 5:
        return {
            'matrix': pd.DataFrame(),
            'chi2': np.nan,
            'p_value': np.nan,
            'dof': 0,
            'agreement_pct': 0,
            'categories': []
        }

    # Compute percentile thresholds
    p1_low = np.percentile(df_clean[col1], percentiles[0])
    p1_high = np.percentile(df_clean[col1], percentiles[1])
    p2_low = np.percentile(df_clean[col2], percentiles[0])
    p2_high = np.percentile(df_clean[col2], percentiles[1])

    def categorize(series, low_thresh, high_thresh):
        # If thresholds collapse (constant series), pd.cut would fail.
        if low_thresh == high_thresh:
            return pd.Series(['Medium'] * len(series), index=series.index)
        return pd.cut(
            series,
            bins=[-np.inf, low_thresh, high_thresh, np.inf],
            labels=['Low', 'Medium', 'High']
        )

    cat1 = categorize(df_clean[col1], p1_low, p1_high)
    cat2 = categorize(df_clean[col2], p2_low, p2_high)

    # Create contingency table
    matrix = pd.crosstab(cat1, cat2, margins=True, margins_name='All')

    # Chi-squared test (exclude margins)
    contingency = matrix.iloc[:-1, :-1].values
    try:
        chi2, p_value, dof, expected = stats.chi2_contingency(contingency)
    except ValueError:
        chi2, p_value, dof = np.nan, np.nan, 0

    # Diagonal agreement
    categories = ['Low', 'Medium', 'High']
    diagonal_sum = 0
    for cat in categories:
        if cat in matrix.index and cat in matrix.columns:
            diagonal_sum += matrix.loc[cat, cat]

    total = matrix.loc['All', 'All']
    agreement_pct = (diagonal_sum / total * 100) if total > 0 else 0

    return {
        'matrix': matrix,
        'chi2': chi2,
        'p_value': p_value,
        'dof': dof,
        'agreement_pct': agreement_pct,
        'categories': categories
    }


def compute_cross_layer_summary(
    aligned_df: pd.DataFrame,
    iostat_col: str = 'iostat_write_mbps',
    oci_col: str = None
) -> Dict:
    """
    Compute summary statistics for cross-layer correlation.

    Args:
        aligned_df: Time-aligned DataFrame
        iostat_col: iostat column name
        oci_col: OCI column name (auto-detected if None)

    Returns:
        Dict with correlation summary
    """
    # Auto-detect OCI column
    if oci_col is None:
        oci_candidates = [c for c in aligned_df.columns
                         if 'VolumeWriteThroughput' in c or 'oci_write' in c.lower()]
        oci_col = oci_candidates[0] if oci_candidates else None

    if iostat_col not in aligned_df.columns:
        return {'error': f'Column {iostat_col} not found'}
    if oci_col is None or oci_col not in aligned_df.columns:
        return {'error': f'OCI column not found'}

    pearson_r, pearson_p = compute_correlation_with_pvalue(
        aligned_df, iostat_col, oci_col, 'pearson'
    )
    spearman_r, spearman_p = compute_correlation_with_pvalue(
        aligned_df, iostat_col, oci_col, 'spearman'
    )
    quadrant = compute_quadrant_matrix(aligned_df, iostat_col, oci_col)

    return {
        'iostat_col': iostat_col,
        'oci_col': oci_col,
        'pearson_r': pearson_r,
        'pearson_p': pearson_p,
        'spearman_r': spearman_r,
        'spearman_p': spearman_p,
        'quadrant_agreement_pct': quadrant['agreement_pct'],
        'quadrant_chi2': quadrant['chi2'],
        'quadrant_p_value': quadrant['p_value'],
        'n_observations': len(aligned_df.dropna(subset=[iostat_col, oci_col])),
    }
