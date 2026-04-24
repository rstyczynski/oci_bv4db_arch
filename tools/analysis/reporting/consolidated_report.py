"""Consolidated sprint correlation report generator."""

import pandas as pd
import numpy as np
from pathlib import Path
from typing import Dict, Any, List, Optional
from datetime import datetime

from .quality_scorer import EvidenceQualityReport

# Import formatting functions - handle both package and direct execution
try:
    from ..correlation.full_correlation import (
        format_correlation_matrix_md,
        format_significant_pairs_md,
        format_cross_layer_md,
    )
except ImportError:
    from correlation.full_correlation import (
        format_correlation_matrix_md,
        format_significant_pairs_md,
        format_cross_layer_md,
    )


def generate_consolidated_report(
    sprint: int,
    fio_results: Dict[str, Any],
    swingbench_results: Dict[str, Any],
    output_dir: Path,
    format: str = 'both'
) -> Dict[str, Path]:
    """
    Generate a single consolidated report for a sprint with both phases.

    Args:
        sprint: Sprint number
        fio_results: FIO phase analysis results
        swingbench_results: Swingbench phase analysis results
        output_dir: Output directory
        format: 'md', 'html', or 'both'

    Returns:
        Dict with paths to generated reports
    """
    paths = {}

    if format in ('md', 'both'):
        md_path = output_dir / f'sprint_{sprint}_correlation_report.md'
        md_content = _generate_markdown(sprint, fio_results, swingbench_results)
        md_path.write_text(md_content)
        paths['md'] = md_path

    if format in ('html', 'both'):
        html_path = output_dir / f'sprint_{sprint}_correlation_report.html'
        html_content = _generate_html(sprint, fio_results, swingbench_results)
        html_path.write_text(html_content)
        paths['html'] = html_path

    return paths


def _generate_markdown(
    sprint: int,
    fio: Dict[str, Any],
    swingbench: Dict[str, Any]
) -> str:
    """Generate consolidated Markdown report."""

    lines = [
        f"# Sprint {sprint} - Correlation Analysis Report",
        "",
        f"**Generated:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
        "",
        "---",
        "",
        "## Table of Contents",
        "",
        "1. [Executive Summary](#executive-summary)",
        "2. [Phase 1: FIO Storage Benchmark](#phase-1-fio-storage-benchmark)",
        "   - [FIO Performance Summary](#fio-performance-summary)",
        "   - [FIO Cross-Layer Correlation](#fio-cross-layer-correlation)",
        "   - [FIO Full Correlation Matrix](#fio-full-correlation-matrix)",
        "3. [Phase 2: Swingbench Database Workload](#phase-2-swingbench-database-workload)",
        "   - [Swingbench Performance Summary](#swingbench-performance-summary)",
        "   - [Swingbench Cross-Layer Correlation](#swingbench-cross-layer-correlation)",
        "   - [Swingbench Full Correlation Matrix](#swingbench-full-correlation-matrix)",
        "4. [Cross-Phase Comparison](#cross-phase-comparison)",
        "5. [Compute Resource Utilization](#compute-resource-utilization)",
        "6. [Anomalies and Findings](#anomalies-and-findings)",
        "7. [Conclusion](#conclusion)",
        "",
        "---",
        "",
    ]

    # Executive Summary
    lines.extend(_md_executive_summary(sprint, fio, swingbench))

    # FIO Phase
    lines.extend(_md_fio_phase(fio))

    # Swingbench Phase
    lines.extend(_md_swingbench_phase(swingbench))

    # Cross-Phase Comparison
    lines.extend(_md_cross_phase_comparison(fio, swingbench))

    # Compute Resource Utilization
    lines.extend(_md_compute_utilization(fio, swingbench))

    # Anomalies and Findings
    lines.extend(_md_anomalies(fio, swingbench))

    # Conclusion
    lines.extend(_md_conclusion(sprint, fio, swingbench))

    return "\n".join(lines)


def _md_executive_summary(sprint: int, fio: Dict, swingbench: Dict) -> List[str]:
    """Generate executive summary section."""
    fio_quality = fio.get('quality', {})
    sb_quality = swingbench.get('quality', {})

    lines = [
        "## Executive Summary",
        "",
        f"Sprint {sprint} benchmark analysis examines cross-layer correlation between:",
        "- **Guest OS measurements** (iostat)",
        "- **OCI Block Volume metrics** (Monitoring API)",
        "- **Workload metrics** (FIO throughput, Swingbench TPS)",
        "",
        "### Overall Results",
        "",
        "| Phase | Score | Grade | Verdict |",
        "|-------|-------|-------|---------|",
        f"| FIO (Storage) | {fio_quality.get('score', 'N/A')}/100 | {fio_quality.get('grade', 'N/A')} | {fio_quality.get('pass_fail', 'N/A')} |",
        f"| Swingbench (Database) | {sb_quality.get('score', 'N/A')}/100 | {sb_quality.get('grade', 'N/A')} | {sb_quality.get('pass_fail', 'N/A')} |",
        "",
        "---",
        "",
    ]
    return lines


def _md_fio_phase(fio: Dict) -> List[str]:
    """Generate FIO phase section."""
    lines = [
        "## Phase 1: FIO Storage Benchmark",
        "",
        "FIO (Flexible I/O Tester) provides direct storage-level benchmarking without database overhead.",
        "",
        "### FIO Performance Summary",
        "",
    ]

    # FIO summary table
    fio_summary = fio.get('fio_summary', [])
    if fio_summary:
        lines.extend([
            "| Job | Read BW (MB/s) | Write BW (MB/s) | Read IOPS | Write IOPS | Read Lat P99 (ms) | Write Lat P99 (ms) |",
            "|-----|----------------|-----------------|-----------|------------|-------------------|-------------------|",
        ])
        for job in fio_summary:
            read_bw = job.get('read_bw_kbps', 0) / 1024
            write_bw = job.get('write_bw_kbps', 0) / 1024
            read_iops = job.get('read_iops', 0)
            write_iops = job.get('write_iops', 0)
            read_lat = job.get('read_lat_p99_us', 0) / 1000
            write_lat = job.get('write_lat_p99_us', 0) / 1000
            lines.append(
                f"| {job.get('job_name', 'N/A')} | {read_bw:.1f} | {write_bw:.1f} | "
                f"{read_iops:.0f} | {write_iops:.0f} | {read_lat:.2f} | {write_lat:.2f} |"
            )
        lines.append("")

    # Correlation section
    lines.extend([
        "### FIO Cross-Layer Correlation",
        "",
        "Correlation between guest iostat measurements and OCI Block Volume metrics.",
        "",
    ])

    corr = fio.get('correlation', {})
    if corr and 'error' not in corr:
        lines.extend([
            "| Metric | iostat vs OCI |",
            "|--------|---------------|",
            f"| Pearson r | {corr.get('pearson_r', 0):.3f} |",
            f"| Pearson p-value | {corr.get('pearson_p', 0):.4f} |",
            f"| Spearman ρ | {corr.get('spearman_r', 0):.3f} |",
            f"| Spearman p-value | {corr.get('spearman_p', 0):.4f} |",
            f"| Aligned Samples | {fio.get('aligned_samples', 0)} |",
            "",
        ])

    # Cross-layer correlations (iostat vs each volume)
    cross_layer = fio.get('cross_layer', {})
    if cross_layer:
        lines.append("### FIO iostat vs OCI Block Volumes")
        lines.append("")
        lines.append(format_cross_layer_md(cross_layer))

    # Full correlation matrix
    full_corr = fio.get('full_correlation', {})
    if full_corr and full_corr.get('matrix') is not None:
        lines.append("### FIO Full Correlation Matrix")
        lines.append("")
        lines.append("Pearson correlations between all available metrics:")
        lines.append("")
        lines.append(format_correlation_matrix_md(full_corr))

        # Significant pairs
        if full_corr.get('significant_pairs'):
            lines.append("### FIO Significant Correlations")
            lines.append("")
            lines.append(format_significant_pairs_md(full_corr))

    lines.append("---")
    lines.append("")
    return lines


def _md_swingbench_phase(swingbench: Dict) -> List[str]:
    """Generate Swingbench phase section."""
    lines = [
        "## Phase 2: Swingbench Database Workload",
        "",
        "Swingbench generates OLTP database workload against Oracle Database Free.",
        "",
        "### Swingbench Performance Summary",
        "",
        "| Metric | Value |",
        "|--------|-------|",
        f"| Average TPS | {swingbench.get('avg_tps', 0):.1f} |",
        f"| Completed Transactions | {swingbench.get('completed_tx', 0):,} |",
        f"| iostat Samples | {swingbench.get('iostat_samples', 0)} |",
        f"| OCI Metrics Entries | {swingbench.get('oci_metrics_count', 0)} |",
        "",
    ]

    # Correlation section
    lines.extend([
        "### Swingbench Cross-Layer Correlation",
        "",
        "Correlation between guest iostat measurements and OCI Block Volume metrics during database workload.",
        "",
    ])

    corr = swingbench.get('correlation', {})
    if corr and 'error' not in corr:
        lines.extend([
            "| Metric | iostat vs OCI |",
            "|--------|---------------|",
            f"| Pearson r | {corr.get('pearson_r', 0):.3f} |",
            f"| Pearson p-value | {corr.get('pearson_p', 0):.4f} |",
            f"| Spearman ρ | {corr.get('spearman_r', 0):.3f} |",
            f"| Spearman p-value | {corr.get('spearman_p', 0):.4f} |",
            f"| Aligned Samples | {swingbench.get('aligned_samples', 0)} |",
            "",
        ])

    # Cross-layer correlations (iostat vs each volume)
    cross_layer = swingbench.get('cross_layer', {})
    if cross_layer:
        lines.append("### Swingbench iostat vs OCI Block Volumes")
        lines.append("")
        lines.append(format_cross_layer_md(cross_layer))

    # Full correlation matrix
    full_corr = swingbench.get('full_correlation', {})
    if full_corr and full_corr.get('matrix') is not None:
        lines.append("### Swingbench Full Correlation Matrix")
        lines.append("")
        lines.append("Pearson correlations between all available metrics:")
        lines.append("")
        lines.append(format_correlation_matrix_md(full_corr))

        # Significant pairs
        if full_corr.get('significant_pairs'):
            lines.append("### Swingbench Significant Correlations")
            lines.append("")
            lines.append(format_significant_pairs_md(full_corr))

    lines.append("---")
    lines.append("")
    return lines


def _md_quadrant_section(phase: str, quadrant: Dict, correlation: Dict = None) -> List[str]:
    """Generate quadrant analysis section."""
    # Get actual variable names from correlation summary
    iostat_var = correlation.get('iostat_col', 'iostat_write_mbps') if correlation else 'iostat_write_mbps'
    oci_var = correlation.get('oci_col', 'OCI_VolumeWriteThroughput') if correlation else 'OCI_VolumeWriteThroughput'

    # Clean up variable names for display
    iostat_display = iostat_var.replace('_', ' ').title()
    oci_display = oci_var.replace('_', ' ')

    lines = [
        f"### {phase} Quadrant Analysis",
        "",
        f"**Variables Compared:**",
        f"- X-axis (rows): `{iostat_var}` (Guest iostat)",
        f"- Y-axis (columns): `{oci_var}` (OCI Monitoring)",
        "",
        "Values binned into terciles (Low: <33rd percentile, Medium: 33-66th, High: >66th).",
        "",
        "| Statistic | Value |",
        "|-----------|-------|",
        f"| Diagonal Agreement | **{quadrant.get('agreement_pct', 0):.1f}%** |",
        f"| Chi-squared | {quadrant.get('chi2', 0):.2f} |",
        f"| P-value | {quadrant.get('p_value', 0):.4f} |",
        "",
    ]

    matrix = quadrant.get('matrix')
    if matrix is not None and not matrix.empty:
        lines.extend([
            f"**Contingency Table:**",
            "",
            f"| {iostat_var} \\ {oci_var} | " + " | ".join(str(c) for c in matrix.columns) + " |",
            "| --- | " + " | ".join(["---"] * len(matrix.columns)) + " |",
        ])
        for idx in matrix.index:
            row = [str(idx)] + [str(matrix.loc[idx, c]) for c in matrix.columns]
            lines.append("| " + " | ".join(row) + " |")
        lines.append("")
        lines.append("*Diagonal cells (Low-Low, Medium-Medium, High-High) indicate agreement between layers.*")
        lines.append("")

    return lines


def _md_cross_phase_comparison(fio: Dict, swingbench: Dict) -> List[str]:
    """Generate cross-phase comparison section."""
    fio_corr = fio.get('correlation', {})
    sb_corr = swingbench.get('correlation', {})

    lines = [
        "## Cross-Phase Comparison",
        "",
        "Comparison of correlation strength between storage-level (FIO) and database-level (Swingbench) workloads.",
        "",
        "| Metric | FIO Phase | Swingbench Phase | Interpretation |",
        "|--------|-----------|------------------|----------------|",
    ]

    fio_r = fio_corr.get('pearson_r', 0)
    sb_r = sb_corr.get('pearson_r', 0)

    fio_interp = _interpret_correlation(fio_r)
    sb_interp = _interpret_correlation(sb_r)

    lines.append(f"| Pearson r | {fio_r:.3f} | {sb_r:.3f} | FIO: {fio_interp}, Swingbench: {sb_interp} |")

    # Best volume match correlation
    fio_best = fio.get('cross_layer', {}).get('best_volume_match', {})
    sb_best = swingbench.get('cross_layer', {}).get('best_volume_match', {})
    fio_best_r = fio_best.get('r', 0) if fio_best else 0
    sb_best_r = sb_best.get('r', 0) if sb_best else 0
    fio_best_vol = fio_best.get('volume', 'N/A') if fio_best else 'N/A'
    sb_best_vol = sb_best.get('volume', 'N/A') if sb_best else 'N/A'
    import math
    if not isinstance(fio_best_r, (int, float)) or math.isnan(fio_best_r):
        fio_best_str = "N/A"
    else:
        fio_best_str = f"{fio_best_vol} (r={fio_best_r:.2f})"
    if not isinstance(sb_best_r, (int, float)) or math.isnan(sb_best_r):
        sb_best_str = "N/A"
    else:
        sb_best_str = f"{sb_best_vol} (r={sb_best_r:.2f})"
    lines.append(f"| Best Volume Match | {fio_best_str} | {sb_best_str} | Which volume shows highest correlation with iostat |")

    fio_samples = fio.get('aligned_samples', 0)
    sb_samples = swingbench.get('aligned_samples', 0)
    lines.append(f"| Aligned Samples | {fio_samples} | {sb_samples} | - |")

    lines.extend([
        "",
        "**Observations:**",
        "",
    ])

    if fio_r > 0.7 and sb_r < 0.5:
        lines.append("- FIO shows strong cross-layer correlation while Swingbench shows weak correlation")
        lines.append("- This is expected due to database caching, WAL buffering, and checkpoint behavior")
        lines.append("- Database I/O patterns are less directly mapped to block volume metrics")
    elif fio_r > 0.5 and sb_r > 0.5:
        lines.append("- Both phases show moderate-to-strong correlation")
        lines.append("- Cross-layer metrics are consistent across workload types")
    else:
        lines.append("- Correlation patterns require further investigation")

    lines.extend(["", "---", ""])
    return lines


def _md_compute_utilization(fio: Dict, swingbench: Dict) -> List[str]:
    """Generate compute utilization section."""
    lines = [
        "## Compute Resource Utilization",
        "",
        "OCI Compute instance metrics during benchmark phases.",
        "",
    ]

    # Extract compute metrics if available
    fio_compute = fio.get('compute_metrics', {})
    sb_compute = swingbench.get('compute_metrics', {})

    if fio_compute or sb_compute:
        lines.extend([
            "| Metric | FIO Phase | Swingbench Phase |",
            "|--------|-----------|------------------|",
        ])

        metrics = ['CpuUtilization', 'MemoryUtilization', 'DiskBytesRead', 'DiskBytesWritten']
        for m in metrics:
            fio_val = fio_compute.get(m, 'N/A')
            sb_val = sb_compute.get(m, 'N/A')
            if isinstance(fio_val, float):
                fio_val = f"{fio_val:.1f}"
            if isinstance(sb_val, float):
                sb_val = f"{sb_val:.1f}"
            lines.append(f"| {m} | {fio_val} | {sb_val} |")
        lines.append("")
    else:
        lines.append("*Compute metrics not available in current analysis.*")
        lines.append("")

    lines.extend(["---", ""])
    return lines


def _md_anomalies(fio: Dict, swingbench: Dict) -> List[str]:
    """Generate anomalies section."""
    lines = [
        "## Anomalies and Findings",
        "",
    ]

    fio_anomalies = fio.get('anomalies', [])
    sb_anomalies = swingbench.get('anomalies', [])

    if not fio_anomalies and not sb_anomalies:
        lines.append("No anomalies detected in either phase.")
        lines.append("")
    else:
        lines.extend([
            "| Phase | Rule | Severity | Message |",
            "|-------|------|----------|---------|",
        ])
        for a in fio_anomalies:
            lines.append(f"| FIO | {a.get('rule_id', 'N/A')} | {a.get('severity', 'N/A')} | {a.get('message', '')} |")
        for a in sb_anomalies:
            lines.append(f"| Swingbench | {a.get('rule_id', 'N/A')} | {a.get('severity', 'N/A')} | {a.get('message', '')} |")
        lines.append("")

    lines.extend(["---", ""])
    return lines


def _md_conclusion(sprint: int, fio: Dict, swingbench: Dict) -> List[str]:
    """Generate conclusion section."""
    fio_q = fio.get('quality', {})
    sb_q = swingbench.get('quality', {})

    lines = [
        "## Conclusion",
        "",
        f"### Sprint {sprint} Evidence Quality Assessment",
        "",
    ]

    # Overall verdict
    fio_pass = fio_q.get('pass_fail', 'N/A')
    sb_pass = sb_q.get('pass_fail', 'N/A')

    if fio_pass == 'PASS' and sb_pass == 'PASS':
        overall = "PASS"
        msg = "Both phases demonstrate acceptable evidence quality."
    elif fio_pass == 'PASS' or sb_pass == 'PASS':
        overall = "PARTIAL"
        msg = "One phase demonstrates acceptable evidence quality while the other requires review."
    else:
        overall = "INCONCLUSIVE"
        msg = "Evidence quality is uncertain for both phases. Results require careful interpretation."

    lines.extend([
        f"**Overall Verdict: {overall}**",
        "",
        msg,
        "",
        "### Key Takeaways",
        "",
    ])

    fio_r = fio.get('correlation', {}).get('pearson_r', 0)
    if fio_r > 0.7:
        lines.append(f"- FIO phase validates cross-layer correlation (r={fio_r:.2f})")
    elif fio_r > 0.5:
        lines.append(f"- FIO phase shows moderate cross-layer correlation (r={fio_r:.2f})")
    else:
        lines.append(f"- FIO phase shows weak cross-layer correlation (r={fio_r:.2f}) - investigate")

    sb_tps = swingbench.get('avg_tps', 0)
    if sb_tps > 0:
        lines.append(f"- Swingbench achieved {sb_tps:.0f} TPS average throughput")

    lines.append("")
    return lines


def _get_best_volume_str(phase_data: Dict) -> str:
    """Get best volume match string for display."""
    import math
    best = phase_data.get('cross_layer', {}).get('best_volume_match', {})
    if not best:
        return "N/A"
    r = best.get('r', float('nan'))
    if not isinstance(r, (int, float)) or math.isnan(r):
        return "N/A"
    return f"{best.get('volume', 'N/A')} (r={r:.2f})"


def _interpret_correlation(r: float) -> str:
    """Interpret correlation coefficient."""
    if pd.isna(r):
        return "undefined"
    if abs(r) >= 0.7:
        return "strong"
    elif abs(r) >= 0.5:
        return "moderate"
    elif abs(r) >= 0.3:
        return "weak"
    else:
        return "negligible"


def _interpret_agreement(fio_pct: float, sb_pct: float) -> str:
    """Interpret quadrant agreement comparison."""
    if fio_pct > 50 and sb_pct > 50:
        return "Both show majority agreement"
    elif fio_pct > sb_pct + 10:
        return "FIO shows better alignment"
    elif sb_pct > fio_pct + 10:
        return "Swingbench shows better alignment"
    else:
        return "Similar alignment levels"


def _generate_html(
    sprint: int,
    fio: Dict[str, Any],
    swingbench: Dict[str, Any]
) -> str:
    """Generate consolidated HTML report."""

    fio_quality = fio.get('quality', {})
    sb_quality = swingbench.get('quality', {})

    # Determine colors
    def grade_color(grade):
        colors = {'A': '#28a745', 'B': '#5cb85c', 'C': '#f0ad4e', 'D': '#d9534f', 'F': '#c9302c'}
        return colors.get(grade, '#666')

    fio_color = grade_color(fio_quality.get('grade', 'C'))
    sb_color = grade_color(sb_quality.get('grade', 'C'))

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Sprint {sprint} - Correlation Analysis Report</title>
    <style>
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
            background: #f5f5f5;
            line-height: 1.6;
        }}
        .container {{ background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }}
        h1 {{ color: #333; border-bottom: 3px solid #007bff; padding-bottom: 15px; }}
        h2 {{ color: #444; margin-top: 40px; border-bottom: 2px solid #ddd; padding-bottom: 10px; }}
        h3 {{ color: #555; }}
        .toc {{ background: #f8f9fa; padding: 20px; border-radius: 8px; margin: 20px 0; }}
        .toc ul {{ list-style: none; padding-left: 20px; }}
        .toc a {{ text-decoration: none; color: #007bff; }}
        .toc a:hover {{ text-decoration: underline; }}
        .summary-cards {{ display: flex; gap: 20px; margin: 20px 0; flex-wrap: wrap; }}
        .card {{
            flex: 1;
            min-width: 250px;
            padding: 20px;
            border-radius: 8px;
            color: white;
            text-align: center;
        }}
        .card.fio {{ background: {fio_color}; }}
        .card.swingbench {{ background: {sb_color}; }}
        .card h3 {{ margin: 0 0 10px 0; color: white; border: none; }}
        .card .score {{ font-size: 36px; font-weight: bold; }}
        .card .verdict {{ font-size: 18px; margin-top: 10px; }}
        table {{ border-collapse: collapse; width: 100%; margin: 15px 0; }}
        th, td {{ border: 1px solid #ddd; padding: 10px; text-align: left; }}
        th {{ background: #f8f9fa; }}
        .phase-section {{ margin: 30px 0; padding: 20px; background: #fafafa; border-radius: 8px; border-left: 4px solid #007bff; }}
        .phase-section.swingbench {{ border-left-color: #6f42c1; }}
        .quadrant-matrix td {{ text-align: center; }}
        .quadrant-matrix .diagonal {{ background: #d4edda; font-weight: bold; }}
        .anomaly-critical {{ color: #d9534f; font-weight: bold; }}
        .anomaly-warning {{ color: #f0ad4e; }}
        .metric-good {{ color: #28a745; }}
        .metric-bad {{ color: #d9534f; }}
    </style>
</head>
<body>
    <div class="container">
        <h1>Sprint {sprint} - Correlation Analysis Report</h1>
        <p>Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</p>

        <div class="toc">
            <h3>Table of Contents</h3>
            <ul>
                <li><a href="#summary">1. Executive Summary</a></li>
                <li><a href="#fio">2. Phase 1: FIO Storage Benchmark</a>
                    <ul>
                        <li><a href="#fio-perf">FIO Performance Summary</a></li>
                        <li><a href="#fio-corr">FIO Cross-Layer Correlation</a></li>
                        <li><a href="#fio-matrix">FIO Full Correlation Matrix</a></li>
                    </ul>
                </li>
                <li><a href="#swingbench">3. Phase 2: Swingbench Database Workload</a>
                    <ul>
                        <li><a href="#sb-perf">Swingbench Performance Summary</a></li>
                        <li><a href="#sb-corr">Swingbench Cross-Layer Correlation</a></li>
                        <li><a href="#sb-matrix">Swingbench Full Correlation Matrix</a></li>
                    </ul>
                </li>
                <li><a href="#comparison">4. Cross-Phase Comparison</a></li>
                <li><a href="#compute">5. Compute Resource Utilization</a></li>
                <li><a href="#anomalies">6. Anomalies and Findings</a></li>
                <li><a href="#conclusion">7. Conclusion</a></li>
            </ul>
        </div>

        <h2 id="summary">1. Executive Summary</h2>
        <div class="summary-cards">
            <div class="card fio">
                <h3>FIO Phase</h3>
                <div class="score">{fio_quality.get('score', 'N/A')}/100</div>
                <div>Grade {fio_quality.get('grade', 'N/A')}</div>
                <div class="verdict">{fio_quality.get('pass_fail', 'N/A')}</div>
            </div>
            <div class="card swingbench">
                <h3>Swingbench Phase</h3>
                <div class="score">{sb_quality.get('score', 'N/A')}/100</div>
                <div>Grade {sb_quality.get('grade', 'N/A')}</div>
                <div class="verdict">{sb_quality.get('pass_fail', 'N/A')}</div>
            </div>
        </div>
        <p>This report analyzes cross-layer correlation between guest OS measurements (iostat),
           OCI Block Volume metrics, and workload metrics (FIO throughput, Swingbench TPS).</p>
"""

    # FIO Phase
    html += _html_fio_section(fio)

    # Swingbench Phase
    html += _html_swingbench_section(swingbench)

    # Cross-Phase Comparison
    html += _html_comparison_section(fio, swingbench)

    # Compute Utilization
    html += _html_compute_section(fio, swingbench)

    # Anomalies
    html += _html_anomalies_section(fio, swingbench)

    # Conclusion
    html += _html_conclusion_section(sprint, fio, swingbench)

    html += """
    </div>
</body>
</html>
"""
    return html


def _html_fio_section(fio: Dict) -> str:
    """Generate FIO section HTML."""
    html = """
        <h2 id="fio">2. Phase 1: FIO Storage Benchmark</h2>
        <div class="phase-section">
            <p>FIO (Flexible I/O Tester) provides direct storage-level benchmarking without database overhead.</p>

            <h3 id="fio-perf">FIO Performance Summary</h3>
"""

    fio_summary = fio.get('fio_summary', [])
    if fio_summary:
        html += """
            <table>
                <tr>
                    <th>Job</th>
                    <th>Read BW (MB/s)</th>
                    <th>Write BW (MB/s)</th>
                    <th>Read IOPS</th>
                    <th>Write IOPS</th>
                    <th>Read P99 (ms)</th>
                    <th>Write P99 (ms)</th>
                </tr>
"""
        for job in fio_summary:
            html += f"""
                <tr>
                    <td>{job.get('job_name', 'N/A')}</td>
                    <td>{job.get('read_bw_kbps', 0) / 1024:.1f}</td>
                    <td>{job.get('write_bw_kbps', 0) / 1024:.1f}</td>
                    <td>{job.get('read_iops', 0):.0f}</td>
                    <td>{job.get('write_iops', 0):.0f}</td>
                    <td>{job.get('read_lat_p99_us', 0) / 1000:.2f}</td>
                    <td>{job.get('write_lat_p99_us', 0) / 1000:.2f}</td>
                </tr>
"""
        html += "</table>"

    # Correlation
    corr = fio.get('correlation', {})
    html += f"""
            <h3 id="fio-corr">FIO Cross-Layer Correlation</h3>
            <p>Correlation between guest iostat measurements and OCI Block Volume metrics.</p>
            <table style="width: auto;">
                <tr><th>Metric</th><th>Value</th></tr>
                <tr><td>Pearson r</td><td class="{'metric-good' if corr.get('pearson_r', 0) > 0.7 else 'metric-bad' if corr.get('pearson_r', 0) < 0.3 else ''}">{corr.get('pearson_r', 0):.3f}</td></tr>
                <tr><td>Pearson p-value</td><td>{corr.get('pearson_p', 0):.4f}</td></tr>
                <tr><td>Spearman ρ</td><td>{corr.get('spearman_r', 0):.3f}</td></tr>
                <tr><td>Spearman p-value</td><td>{corr.get('spearman_p', 0):.4f}</td></tr>
                <tr><td>Aligned Samples</td><td>{fio.get('aligned_samples', 0)}</td></tr>
            </table>
"""

    # Cross-layer correlations (iostat vs each volume)
    cross_layer = fio.get('cross_layer', {})
    if cross_layer:
        html += _html_cross_layer_table("fio", cross_layer)

    # Full correlation matrix
    full_corr = fio.get('full_correlation', {})
    if full_corr and full_corr.get('matrix') is not None:
        html += _html_full_correlation_matrix("fio-matrix", "FIO", full_corr)

    html += "</div>"
    return html


def _html_swingbench_section(swingbench: Dict) -> str:
    """Generate Swingbench section HTML."""
    html = f"""
        <h2 id="swingbench">3. Phase 2: Swingbench Database Workload</h2>
        <div class="phase-section swingbench">
            <p>Swingbench generates OLTP database workload against Oracle Database Free.</p>

            <h3 id="sb-perf">Swingbench Performance Summary</h3>
            <table style="width: auto;">
                <tr><th>Metric</th><th>Value</th></tr>
                <tr><td>Average TPS</td><td><strong>{swingbench.get('avg_tps', 0):.1f}</strong></td></tr>
                <tr><td>Completed Transactions</td><td>{swingbench.get('completed_tx', 0):,}</td></tr>
                <tr><td>iostat Samples</td><td>{swingbench.get('iostat_samples', 0)}</td></tr>
                <tr><td>OCI Metrics Entries</td><td>{swingbench.get('oci_metrics_count', 0)}</td></tr>
            </table>
"""

    corr = swingbench.get('correlation', {})
    html += f"""
            <h3 id="sb-corr">Swingbench Cross-Layer Correlation</h3>
            <p>Correlation between guest iostat measurements and OCI Block Volume metrics during database workload.</p>
            <table style="width: auto;">
                <tr><th>Metric</th><th>Value</th></tr>
                <tr><td>Pearson r</td><td>{corr.get('pearson_r', 0):.3f}</td></tr>
                <tr><td>Pearson p-value</td><td>{corr.get('pearson_p', 0):.4f}</td></tr>
                <tr><td>Spearman ρ</td><td>{corr.get('spearman_r', 0):.3f}</td></tr>
                <tr><td>Spearman p-value</td><td>{corr.get('spearman_p', 0):.4f}</td></tr>
                <tr><td>Aligned Samples</td><td>{swingbench.get('aligned_samples', 0)}</td></tr>
            </table>
"""

    # Cross-layer correlations (iostat vs each volume)
    cross_layer = swingbench.get('cross_layer', {})
    if cross_layer:
        html += _html_cross_layer_table("swingbench", cross_layer)

    # Full correlation matrix
    full_corr = swingbench.get('full_correlation', {})
    if full_corr and full_corr.get('matrix') is not None:
        html += _html_full_correlation_matrix("sb-matrix", "Swingbench", full_corr)

    html += "</div>"
    return html


def _html_cross_layer_table(phase: str, cross_layer: Dict) -> str:
    """Generate cross-layer correlation table HTML."""
    html = f"""
            <h3 id="{phase}-volumes">{phase.title()} iostat vs OCI Block Volumes</h3>
            <p>Correlation of guest iostat with each OCI Block Volume:</p>
            <table>
                <tr><th>Volume</th><th>Pearson r</th><th>p-value</th><th>iostat (MB/s)</th><th>OCI (MB/s)</th><th>Match</th></tr>
"""
    vol_corrs = cross_layer.get('iostat_vs_volumes', [])
    for v in vol_corrs:
        r = v.get('r', float('nan'))
        p = v.get('p', float('nan'))
        import math
        if math.isnan(r):
            match = "N/A"
            r_str = "N/A"
            p_str = "N/A"
        else:
            match = "Strong" if abs(r) >= 0.7 else "Moderate" if abs(r) >= 0.5 else "Weak" if abs(r) >= 0.3 else "None"
            r_str = f"{r:.3f}"
            p_str = f"{p:.4f}" if not math.isnan(p) else "N/A"
        html += f"""
                <tr>
                    <td>{v.get('volume', 'N/A')}</td>
                    <td>{r_str}</td>
                    <td>{p_str}</td>
                    <td>{v.get('iostat_mean', 0):.1f}</td>
                    <td>{v.get('volume_mean', 0):.1f}</td>
                    <td>{match}</td>
                </tr>
"""
    html += "</table>"

    best = cross_layer.get('best_volume_match')
    if best and not math.isnan(best.get('r', float('nan'))):
        html += f"<p><strong>Best match:</strong> <code>{best['volume']}</code> (r = {best['r']:.3f})</p>"

    boot = cross_layer.get('boot_volume_correlation')
    if boot and not math.isnan(boot.get('r', float('nan'))):
        html += f"<p><strong>Boot volume correlation:</strong> r = {boot['r']:.3f} (p = {boot['p']:.4f})</p>"

    # Lagged per-volume matching
    lagged = cross_layer.get('lagged_per_volume_match', {})
    if lagged:
        html += """
            <h4>Lagged Per-Volume Correlation (Best Lag)</h4>
            <p>Best Pearson correlation over lag ±0..5 minutes for each matched iostat↔OCI pair.</p>
            <table>
                <tr><th>iostat Volume</th><th>OCI Volume</th><th>Best Lag (min)</th><th>Pearson r</th><th>p-value</th><th>N</th></tr>
        """
        for _, v in sorted(lagged.items()):
            r = v.get('pearson_r', float('nan'))
            p = v.get('pearson_p', float('nan'))
            lag = v.get('best_lag_min', None)
            nobs = v.get('n_observations', 0)
            iostat_vol = v.get('iostat_col', '').replace('_write_mbps', '').replace('_read_mbps', '')
            oci_vol = v.get('oci_col', '').split('_')[0]
            import math
            r_str = "N/A" if (not isinstance(r, (int, float)) or math.isnan(r)) else f"{r:.3f}"
            p_str = "N/A" if (not isinstance(p, (int, float)) or math.isnan(p)) else f"{p:.4f}"
            lag_str = "N/A" if lag is None else str(lag)
            html += f"""
                <tr>
                    <td>{iostat_vol}</td>
                    <td>{oci_vol}</td>
                    <td>{lag_str}</td>
                    <td>{r_str}</td>
                    <td>{p_str}</td>
                    <td>{nobs}</td>
                </tr>
            """
        html += "</table>"

    compute = cross_layer.get('iostat_vs_compute')
    if compute and isinstance(compute, dict) and not math.isnan(compute.get('r', float('nan'))):
        html += f"""
            <h4>iostat vs Compute DiskBytesWritten</h4>
            <ul>
                <li>Pearson r: {compute['r']:.3f} (p = {compute['p']:.4f})</li>
                <li>iostat mean: {compute['iostat_mean']:.1f} MB/s</li>
                <li>Compute DiskBytes mean: {compute['compute_mean']:.1f} MB/s</li>
            </ul>
"""
    return html


def _html_full_correlation_matrix(anchor: str, phase: str, full_corr: Dict) -> str:
    """Generate full correlation matrix HTML."""
    import pandas as pd
    import numpy as np

    matrix = full_corr.get('matrix')
    if matrix is None or (isinstance(matrix, pd.DataFrame) and matrix.empty):
        return ""

    html = f"""
            <h3 id="{anchor}">{phase} Full Correlation Matrix</h3>
            <p>Pearson correlations between all available metrics:</p>
            <table style="font-size: 12px;">
                <tr><th>Variable</th>
"""

    # Shorten column names
    def shorten(name):
        replacements = [
            ('VolumeWriteThroughput', 'Write'),
            ('VolumeReadThroughput', 'Read'),
            ('VolumeWriteOps', 'WrOps'),
            ('VolumeReadOps', 'RdOps'),
            ('compute_', ''),
            ('iostat_', 'io_'),
            ('Utilization', 'Util'),
            ('DiskBytes', 'Disk'),
        ]
        result = name
        for old, new in replacements:
            result = result.replace(old, new)
        return result[:15]

    # Limit columns for display
    cols = list(matrix.columns)[:8]
    for col in cols:
        html += f"<th>{shorten(col)}</th>"
    html += "</tr>"

    for idx in cols:
        html += f"<tr><th>{shorten(idx)}</th>"
        for col in cols:
            val = matrix.loc[idx, col]
            if pd.isna(val):
                html += "<td>-</td>"
            elif idx == col:
                html += "<td>1.00</td>"
            elif abs(val) >= 0.7:
                html += f'<td style="background:#d4edda;font-weight:bold;">{val:.2f}</td>'
            elif abs(val) >= 0.5:
                html += f'<td style="background:#fff3cd;">{val:.2f}</td>'
            else:
                html += f"<td>{val:.2f}</td>"
        html += "</tr>"

    html += """
            </table>
            <p><em>Green/Bold: |r| >= 0.7, Yellow: |r| >= 0.5</em></p>
"""

    # Significant pairs
    pairs = full_corr.get('significant_pairs', [])[:10]
    if pairs:
        html += f"""
            <h4>{phase} Significant Correlations</h4>
            <table>
                <tr><th>Variable 1</th><th>Variable 2</th><th>Pearson r</th><th>p-value</th><th>Strength</th></tr>
"""
        for p in pairs:
            html += f"""
                <tr>
                    <td>{shorten(p['var1'])}</td>
                    <td>{shorten(p['var2'])}</td>
                    <td>{p['r']:.3f}</td>
                    <td>{p['p']:.4f}</td>
                    <td>{p['strength']}</td>
                </tr>
"""
        html += "</table>"

    return html


def _html_quadrant_table(anchor: str, phase: str, quadrant: Dict, correlation: Dict = None) -> str:
    """Generate quadrant analysis HTML."""
    # Get actual variable names
    iostat_var = correlation.get('iostat_col', 'iostat_write_mbps') if correlation else 'iostat_write_mbps'
    oci_var = correlation.get('oci_col', 'OCI_VolumeWriteThroughput') if correlation else 'OCI_VolumeWriteThroughput'

    html = f"""
            <h3 id="{anchor}">{phase} Quadrant Analysis</h3>
            <p><strong>Variables Compared:</strong></p>
            <ul>
                <li>X-axis (rows): <code>{iostat_var}</code> (Guest iostat)</li>
                <li>Y-axis (columns): <code>{oci_var}</code> (OCI Monitoring)</li>
            </ul>
            <p>Values binned into terciles (Low: &lt;33rd percentile, Medium: 33-66th, High: &gt;66th).</p>
            <table style="width: auto; margin-bottom: 15px;">
                <tr><td>Diagonal Agreement:</td><td><strong>{quadrant.get('agreement_pct', 0):.1f}%</strong></td></tr>
                <tr><td>Chi-squared:</td><td>{quadrant.get('chi2', 0):.2f}</td></tr>
                <tr><td>P-value:</td><td>{quadrant.get('p_value', 0):.4f}</td></tr>
            </table>
"""

    matrix = quadrant.get('matrix')
    if matrix is not None and not matrix.empty:
        html += f"""
            <p><strong>Contingency Table:</strong></p>
            <table class="quadrant-matrix" style="width: auto;">
                <tr><th>{iostat_var} \\ {oci_var}</th>
"""
        for col in matrix.columns:
            html += f"<th>{col}</th>"
        html += "</tr>"

        diag_cats = ['Low', 'Medium', 'High']
        for idx in matrix.index:
            html += f"<tr><th>{idx}</th>"
            for col in matrix.columns:
                val = matrix.loc[idx, col]
                is_diag = str(idx) == str(col) and str(idx) in diag_cats
                cell_class = ' class="diagonal"' if is_diag else ''
                html += f"<td{cell_class}>{val}</td>"
            html += "</tr>"
        html += "</table>"
        html += "<p><em>Diagonal cells (Low-Low, Medium-Medium, High-High) indicate agreement between layers.</em></p>"

    return html


def _html_comparison_section(fio: Dict, swingbench: Dict) -> str:
    """Generate cross-phase comparison HTML."""
    fio_corr = fio.get('correlation', {})
    sb_corr = swingbench.get('correlation', {})
    fio_r = fio_corr.get('pearson_r', 0)
    sb_r = sb_corr.get('pearson_r', 0)

    html = f"""
        <h2 id="comparison">4. Cross-Phase Comparison</h2>
        <p>Comparison of correlation strength between storage-level (FIO) and database-level (Swingbench) workloads.</p>
        <table>
            <tr>
                <th>Metric</th>
                <th>FIO Phase</th>
                <th>Swingbench Phase</th>
            </tr>
            <tr>
                <td>Pearson r (iostat vs OCI)</td>
                <td>{fio_r:.3f}</td>
                <td>{sb_r:.3f}</td>
            </tr>
            <tr>
                <td>Best Volume Match</td>
                <td>{_get_best_volume_str(fio)}</td>
                <td>{_get_best_volume_str(swingbench)}</td>
            </tr>
            <tr>
                <td>Aligned Samples</td>
                <td>{fio.get('aligned_samples', 0)}</td>
                <td>{swingbench.get('aligned_samples', 0)}</td>
            </tr>
        </table>
"""
    return html


def _html_compute_section(fio: Dict, swingbench: Dict) -> str:
    """Generate compute utilization HTML."""
    html = """
        <h2 id="compute">5. Compute Resource Utilization</h2>
        <p>OCI Compute instance metrics during benchmark phases.</p>
"""

    fio_compute = fio.get('compute_metrics', {})
    sb_compute = swingbench.get('compute_metrics', {})

    if fio_compute or sb_compute:
        html += """
        <table>
            <tr><th>Metric</th><th>FIO Phase</th><th>Swingbench Phase</th></tr>
"""
        for m in ['CpuUtilization', 'MemoryUtilization', 'DiskBytesRead', 'DiskBytesWritten']:
            fio_val = fio_compute.get(m, 'N/A')
            sb_val = sb_compute.get(m, 'N/A')
            html += f"<tr><td>{m}</td><td>{fio_val}</td><td>{sb_val}</td></tr>"
        html += "</table>"
    else:
        html += "<p><em>Compute metrics not available in current analysis.</em></p>"

    return html


def _html_anomalies_section(fio: Dict, swingbench: Dict) -> str:
    """Generate anomalies section HTML."""
    fio_anomalies = fio.get('anomalies', [])
    sb_anomalies = swingbench.get('anomalies', [])

    html = """
        <h2 id="anomalies">6. Anomalies and Findings</h2>
"""

    if not fio_anomalies and not sb_anomalies:
        html += "<p>No anomalies detected in either phase.</p>"
    else:
        html += """
        <table>
            <tr><th>Phase</th><th>Rule</th><th>Severity</th><th>Message</th></tr>
"""
        for a in fio_anomalies:
            sev_class = 'anomaly-critical' if a.get('severity') == 'critical' else 'anomaly-warning'
            html += f"<tr><td>FIO</td><td>{a.get('rule_id', 'N/A')}</td><td class=\"{sev_class}\">{a.get('severity', 'N/A')}</td><td>{a.get('message', '')}</td></tr>"
        for a in sb_anomalies:
            sev_class = 'anomaly-critical' if a.get('severity') == 'critical' else 'anomaly-warning'
            html += f"<tr><td>Swingbench</td><td>{a.get('rule_id', 'N/A')}</td><td class=\"{sev_class}\">{a.get('severity', 'N/A')}</td><td>{a.get('message', '')}</td></tr>"
        html += "</table>"

    return html


def _html_conclusion_section(sprint: int, fio: Dict, swingbench: Dict) -> str:
    """Generate conclusion section HTML."""
    fio_q = fio.get('quality', {})
    sb_q = swingbench.get('quality', {})

    fio_pass = fio_q.get('pass_fail', 'N/A')
    sb_pass = sb_q.get('pass_fail', 'N/A')

    if fio_pass == 'PASS' and sb_pass == 'PASS':
        overall = "PASS"
        overall_color = "#28a745"
    elif fio_pass == 'PASS' or sb_pass == 'PASS':
        overall = "PARTIAL"
        overall_color = "#f0ad4e"
    else:
        overall = "INCONCLUSIVE"
        overall_color = "#d9534f"

    html = f"""
        <h2 id="conclusion">7. Conclusion</h2>
        <h3>Sprint {sprint} Evidence Quality Assessment</h3>
        <p style="font-size: 24px; font-weight: bold; color: {overall_color};">Overall Verdict: {overall}</p>
"""
    return html
