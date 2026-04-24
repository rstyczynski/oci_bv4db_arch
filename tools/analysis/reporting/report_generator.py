"""Report generation for correlation analysis."""

import pandas as pd
import numpy as np
from pathlib import Path
from typing import Dict, Any, List, Optional
from datetime import datetime

from .quality_scorer import EvidenceQualityReport, format_quality_summary


def generate_markdown_report(
    sprint: int,
    phase: str,
    quality_report: EvidenceQualityReport,
    correlation_summary: Dict[str, Any],
    anomalies: List[Any],
    quadrant_result: Dict[str, Any] = None,
    output_path: Optional[Path] = None
) -> str:
    """
    Generate Markdown correlation report.

    Args:
        sprint: Sprint number
        phase: 'fio' or 'swingbench'
        quality_report: Evidence quality assessment
        correlation_summary: Correlation statistics
        anomalies: List of detected anomalies
        quadrant_result: Quadrant correlation matrix result
        output_path: Optional path to save report

    Returns:
        Markdown report string
    """
    phase_desc = "Storage-Level FIO Benchmark" if phase == 'fio' else "Database Workload (Swingbench)"
    lines = [
        f"# Sprint {sprint} - {phase.upper()} Phase Correlation Report",
        "",
        f"**Phase:** {phase_desc}",
        "",
        f"**Generated:** {datetime.now().isoformat()}",
        "",
        "---",
        "",
    ]

    # Quality summary
    lines.append(format_quality_summary(quality_report))
    lines.append("")
    lines.append("---")
    lines.append("")

    # Correlation details
    lines.extend([
        "## Correlation Analysis",
        "",
        "### Cross-Layer Correlation",
        "",
        f"| Metric | Value |",
        f"|--------|-------|",
        f"| Pearson r | {correlation_summary.get('pearson_r', 'N/A'):.3f} |",
        f"| Pearson p-value | {correlation_summary.get('pearson_p', 'N/A'):.4f} |",
        f"| Spearman r | {correlation_summary.get('spearman_r', 'N/A'):.3f} |",
        f"| Spearman p-value | {correlation_summary.get('spearman_p', 'N/A'):.4f} |",
        f"| Observations | {correlation_summary.get('n_observations', 0)} |",
        "",
    ])

    # Quadrant analysis
    if quadrant_result and 'matrix' in quadrant_result:
        lines.extend([
            "---",
            "",
            "## Quadrant Correlation Matrix",
            "",
            "Categorical analysis binning throughput into Low/Medium/High terciles.",
            "",
            "| Statistic | Value |",
            "|-----------|-------|",
            f"| Diagonal Agreement | **{quadrant_result.get('agreement_pct', 0):.1f}%** |",
            f"| Chi-squared | {quadrant_result.get('chi2', 0):.2f} |",
            f"| P-value | {quadrant_result.get('p_value', 0):.4f} |",
            "",
            "### Contingency Table (Guest iostat vs OCI Metrics)",
            "",
        ])
        matrix = quadrant_result.get('matrix', pd.DataFrame())
        if not matrix.empty:
            # Convert to markdown table
            lines.append("| " + " | ".join(["iostat \\ OCI"] + [str(c) for c in matrix.columns]) + " |")
            lines.append("| " + " | ".join(["---"] * (len(matrix.columns) + 1)) + " |")
            for idx in matrix.index:
                row_values = [str(idx)] + [str(matrix.loc[idx, c]) for c in matrix.columns]
                lines.append("| " + " | ".join(row_values) + " |")
            lines.append("")
            lines.append("*Diagonal cells show agreement between observation layers.*")
            lines.append("")

    # Anomalies
    lines.extend([
        "## Anomaly Detection",
        "",
    ])

    if anomalies:
        lines.extend([
            f"| Rule | Severity | Message |",
            f"|------|----------|---------|",
        ])
        for a in anomalies:
            rule_id = getattr(a, 'rule_id', 'N/A')
            severity = getattr(a, 'severity', 'N/A')
            message = getattr(a, 'message', str(a))
            lines.append(f"| {rule_id} | {severity} | {message} |")
        lines.append("")
    else:
        lines.append("No anomalies detected.")
        lines.append("")

    # Verdict
    lines.extend([
        "---",
        "",
        "## Verdict",
        "",
        f"**Sprint {sprint} {phase.upper()} Phase: {quality_report.pass_fail}**",
        "",
    ])

    if quality_report.pass_fail == 'PASS':
        lines.append("Evidence quality is acceptable. Cross-layer correlation confirms expected behavior.")
    elif quality_report.pass_fail == 'INCONCLUSIVE':
        lines.append("Evidence quality is uncertain. Review recommendations before accepting results.")
    else:
        lines.append("Evidence quality is insufficient. Sprint results should be marked as failed or require rerun.")

    report = "\n".join(lines)

    if output_path:
        output_path = Path(output_path)
        output_path.write_text(report)

    return report


def generate_html_report(
    sprint: int,
    phase: str,
    quality_report: EvidenceQualityReport,
    correlation_summary: Dict[str, Any],
    anomalies: List[Any],
    quadrant_result: Dict[str, Any] = None,
    output_path: Optional[Path] = None
) -> str:
    """
    Generate HTML correlation report.

    Args:
        sprint: Sprint number
        phase: 'fio' or 'swingbench'
        quality_report: Evidence quality assessment
        correlation_summary: Correlation statistics
        anomalies: List of detected anomalies
        quadrant_result: Quadrant correlation matrix result
        output_path: Optional path to save report

    Returns:
        HTML report string
    """
    # Color coding
    grade_colors = {
        'A': '#28a745',  # Green
        'B': '#5cb85c',  # Light green
        'C': '#f0ad4e',  # Orange
        'D': '#d9534f',  # Red
        'F': '#c9302c',  # Dark red
    }
    verdict_colors = {
        'PASS': '#28a745',
        'INCONCLUSIVE': '#f0ad4e',
        'FAIL': '#d9534f',
    }

    grade_color = grade_colors.get(quality_report.grade, '#666')
    verdict_color = verdict_colors.get(quality_report.pass_fail, '#666')

    phase_desc = "Storage-Level FIO Benchmark" if phase == 'fio' else "Database Workload (Swingbench)"
    phase_color = "#17a2b8" if phase == 'fio' else "#6f42c1"

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Sprint {sprint} - {phase.upper()} Phase Correlation Report</title>
    <style>
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
            background: #f5f5f5;
        }}
        .container {{ background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }}
        h1 {{ color: #333; border-bottom: 2px solid #007bff; padding-bottom: 10px; }}
        h2 {{ color: #555; margin-top: 30px; }}
        .phase-badge {{
            display: inline-block;
            padding: 8px 16px;
            background: {phase_color};
            color: white;
            border-radius: 4px;
            font-weight: bold;
            font-size: 14px;
            margin-bottom: 15px;
        }}
        .score-card {{
            display: inline-block;
            padding: 20px 40px;
            background: {grade_color};
            color: white;
            border-radius: 8px;
            font-size: 24px;
            font-weight: bold;
            margin: 10px 0;
        }}
        .verdict {{
            display: inline-block;
            padding: 10px 20px;
            background: {verdict_color};
            color: white;
            border-radius: 4px;
            font-weight: bold;
        }}
        table {{ border-collapse: collapse; width: 100%; margin: 15px 0; }}
        th, td {{ border: 1px solid #ddd; padding: 10px; text-align: left; }}
        th {{ background: #f8f9fa; }}
        .critical {{ color: #d9534f; font-weight: bold; }}
        .warning {{ color: #f0ad4e; }}
        .finding {{ padding: 8px; margin: 5px 0; background: #f8f9fa; border-left: 3px solid #007bff; }}
        .recommendation {{ padding: 8px; margin: 5px 0; background: #fff3cd; border-left: 3px solid #f0ad4e; }}
        pre {{ background: #f8f9fa; padding: 15px; border-radius: 4px; overflow-x: auto; }}
        .progress-bar {{
            background: #e9ecef;
            border-radius: 4px;
            height: 20px;
            margin: 5px 0;
        }}
        .progress-fill {{
            height: 100%;
            border-radius: 4px;
            background: linear-gradient(90deg, #28a745, #5cb85c);
        }}
        .quadrant-matrix {{
            width: auto;
            margin: 20px auto;
        }}
        .quadrant-matrix td, .quadrant-matrix th {{
            text-align: center;
            min-width: 60px;
        }}
        .quadrant-matrix .diagonal {{
            background: #d4edda;
            font-weight: bold;
        }}
    </style>
</head>
<body>
    <div class="container">
        <h1>Sprint {sprint} - {phase.upper()} Phase</h1>
        <div class="phase-badge">{phase_desc}</div>
        <p>Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</p>

        <div class="score-card">
            Score: {quality_report.score}/100 (Grade {quality_report.grade})
        </div>
        <div class="verdict">{quality_report.pass_fail}</div>

        <h2>Component Scores</h2>
        <table>
            <tr>
                <th>Component</th>
                <th>Score</th>
                <th>Progress</th>
                <th>Details</th>
            </tr>
            <tr>
                <td>Cross-layer Correlation</td>
                <td>{quality_report.correlation_score}/25</td>
                <td><div class="progress-bar"><div class="progress-fill" style="width: {quality_report.correlation_score*4}%"></div></div></td>
                <td>r = {quality_report.cross_layer_correlation:.3f}</td>
            </tr>
            <tr>
                <td>Anomaly Check</td>
                <td>{quality_report.anomaly_score}/25</td>
                <td><div class="progress-bar"><div class="progress-fill" style="width: {quality_report.anomaly_score*4}%"></div></div></td>
                <td>{quality_report.critical_anomalies} critical, {quality_report.anomaly_count} total</td>
            </tr>
            <tr>
                <td>Topology Match</td>
                <td>{quality_report.topology_score}/25</td>
                <td><div class="progress-bar"><div class="progress-fill" style="width: {quality_report.topology_score*4}%"></div></div></td>
                <td>{'OK' if quality_report.topology_match else 'MISMATCH'}</td>
            </tr>
            <tr>
                <td>Time Coverage</td>
                <td>{quality_report.coverage_score}/25</td>
                <td><div class="progress-bar"><div class="progress-fill" style="width: {quality_report.coverage_score*4}%"></div></div></td>
                <td>{quality_report.time_coverage_pct:.0f}%</td>
            </tr>
        </table>

        <h2>Correlation Analysis</h2>
        <table>
            <tr><th>Metric</th><th>Value</th></tr>
            <tr><td>Pearson r</td><td>{correlation_summary.get('pearson_r', 'N/A'):.3f}</td></tr>
            <tr><td>Pearson p-value</td><td>{correlation_summary.get('pearson_p', 'N/A'):.4f}</td></tr>
            <tr><td>Spearman r</td><td>{correlation_summary.get('spearman_r', 'N/A'):.3f}</td></tr>
            <tr><td>Spearman p-value</td><td>{correlation_summary.get('spearman_p', 'N/A'):.4f}</td></tr>
            <tr><td>Observations</td><td>{correlation_summary.get('n_observations', 0)}</td></tr>
        </table>

"""

    # Add quadrant section
    if quadrant_result and quadrant_result.get('matrix') is not None:
        matrix = quadrant_result.get('matrix', pd.DataFrame())
        if not matrix.empty:
            html += f"""
        <h2>Quadrant Correlation Matrix</h2>
        <p>Categorical analysis binning throughput into Low/Medium/High terciles.</p>
        <table style="width: auto; margin-bottom: 15px;">
            <tr><td><strong>Diagonal Agreement:</strong></td><td><strong>{quadrant_result.get('agreement_pct', 0):.1f}%</strong></td></tr>
            <tr><td>Chi-squared:</td><td>{quadrant_result.get('chi2', 0):.2f}</td></tr>
            <tr><td>P-value:</td><td>{quadrant_result.get('p_value', 0):.4f}</td></tr>
        </table>
        <h3>Contingency Table (Guest iostat vs OCI Metrics)</h3>
        <table class="quadrant-matrix">
            <tr>
                <th>iostat \\ OCI</th>
"""
            for col in matrix.columns:
                html += f"                <th>{col}</th>\n"
            html += "            </tr>\n"

            diag_categories = ['Low', 'Medium', 'High']
            for idx in matrix.index:
                html += f"            <tr>\n                <th>{idx}</th>\n"
                for col in matrix.columns:
                    val = matrix.loc[idx, col]
                    is_diag = str(idx) == str(col) and str(idx) in diag_categories
                    cell_class = ' class="diagonal"' if is_diag else ''
                    html += f"                <td{cell_class}>{val}</td>\n"
                html += "            </tr>\n"

            html += """        </table>
        <p><em>Diagonal cells (highlighted) show agreement between observation layers.</em></p>
"""

    html += """

        <h2>Anomalies</h2>
"""

    if not anomalies:
        html += "        <p>No anomalies detected.</p>\n"
    else:
        html += """
        <table>
            <tr><th>Rule</th><th>Severity</th><th>Message</th></tr>
"""
        for a in anomalies:
            severity_class = 'critical' if getattr(a, 'severity', '') == 'critical' else 'warning'
            html += f"""
            <tr>
                <td>{getattr(a, 'rule_id', 'N/A')}</td>
                <td class="{severity_class}">{getattr(a, 'severity', 'N/A')}</td>
                <td>{getattr(a, 'message', str(a))}</td>
            </tr>
"""
        html += "</table>"

    html += """
        <h2>Findings</h2>
"""
    for f in quality_report.findings:
        html += f'<div class="finding">{f}</div>\n'

    if quality_report.recommendations:
        html += """
        <h2>Recommendations</h2>
"""
        for r in quality_report.recommendations:
            html += f'<div class="recommendation">{r}</div>\n'

    html += f"""
        <h2>Verdict</h2>
        <p><strong>Sprint {sprint} {phase.upper()} Phase: <span class="verdict">{quality_report.pass_fail}</span></strong></p>
    </div>
</body>
</html>
"""

    if output_path:
        output_path = Path(output_path)
        output_path.write_text(html)

    return html
