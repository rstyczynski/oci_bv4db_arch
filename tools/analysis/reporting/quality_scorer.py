"""Evidence quality scoring for benchmark validation."""

from dataclasses import dataclass, field
from typing import List, Dict, Any
import pandas as pd
import numpy as np


@dataclass
class EvidenceQualityReport:
    """Evidence quality assessment report."""
    sprint: int
    phase: str
    score: int  # 0-100
    grade: str  # A, B, C, D, F
    pass_fail: str  # PASS, INCONCLUSIVE, FAIL

    # Component scores
    cross_layer_correlation: float
    correlation_score: int
    anomaly_count: int
    critical_anomalies: int
    anomaly_score: int
    topology_match: bool
    topology_score: int
    time_coverage_pct: float
    coverage_score: int

    # Details
    findings: List[str] = field(default_factory=list)
    recommendations: List[str] = field(default_factory=list)


def compute_evidence_quality(
    sprint: int,
    phase: str,
    aligned_df: pd.DataFrame,
    anomalies: List[Any],
    correlation_summary: Dict[str, Any] = None,
    expected_duration_min: float = 15
) -> EvidenceQualityReport:
    """
    Compute evidence quality score.

    Scoring (0-100):
    - Cross-layer correlation >= 0.7: +25 points
    - No critical anomalies: +25 points
    - Topology match (expected devices active): +25 points
    - Time coverage >= 80%: +25 points

    Grades:
    - A: 90-100 (Strong evidence)
    - B: 75-89 (Acceptable evidence)
    - C: 50-74 (Weak evidence)
    - D: 25-49 (Insufficient evidence)
    - F: 0-24 (Failed evidence)

    Pass/Fail:
    - PASS: Grade A or B with no critical anomalies
    - INCONCLUSIVE: Grade C or critical anomalies present
    - FAIL: Grade D or F
    """
    correlation_summary = correlation_summary or {}
    findings = []
    recommendations = []

    # 1. Cross-layer correlation score
    cross_corr = correlation_summary.get('pearson_r', np.nan)
    if pd.notna(cross_corr):
        if cross_corr >= 0.7:
            correlation_score = 25
            findings.append(f"Cross-layer correlation {cross_corr:.2f} >= 0.7 threshold")
        elif cross_corr >= 0.5:
            correlation_score = 15
            findings.append(f"Cross-layer correlation {cross_corr:.2f} moderate (0.5-0.7)")
            recommendations.append("Investigate sources of correlation divergence")
        else:
            correlation_score = 0
            findings.append(f"Cross-layer correlation {cross_corr:.2f} below 0.5")
            recommendations.append("Critical: iostat and OCI metrics do not correlate")
    else:
        cross_corr = 0.0
        correlation_score = 0
        findings.append("Cross-layer correlation: insufficient data")
        recommendations.append("Ensure both iostat and OCI metrics are captured")

    # 2. Anomaly score
    critical_count = sum(1 for a in anomalies if getattr(a, 'severity', '') == 'critical')
    warning_count = sum(1 for a in anomalies if getattr(a, 'severity', '') == 'warning')

    if critical_count == 0:
        anomaly_score = 25
        findings.append("No critical anomalies detected")
    elif critical_count <= 2:
        anomaly_score = 10
        findings.append(f"{critical_count} critical anomalies detected")
        for a in anomalies:
            if getattr(a, 'severity', '') == 'critical':
                recommendations.append(f"Fix: {getattr(a, 'message', a)}")
    else:
        anomaly_score = 0
        findings.append(f"{critical_count} critical anomalies detected")
        recommendations.append("Multiple critical issues require resolution")

    # 3. Topology score
    # Simplified: check if expected columns have data, plus phase-specific topology sanity checks.
    topology_ok = True
    if not aligned_df.empty:
        data_cols = [c for c in aligned_df.columns if 'data' in c.lower()]
        if data_cols:
            data_activity = any(aligned_df[c].mean() > 0 for c in data_cols)
            if not data_activity:
                topology_ok = False

        # Swingbench-specific: reject runs that are dominated by boot-volume iostat throughput.
        if phase.lower() == 'swingbench' and 'iostat_boot_mbps' in aligned_df.columns:
            boot = pd.to_numeric(aligned_df.get('iostat_boot_mbps'), errors='coerce')
            data = pd.to_numeric(aligned_df.get('iostat_data_mbps', 0), errors='coerce')
            redo = pd.to_numeric(aligned_df.get('iostat_redo_mbps', 0), errors='coerce')
            fra = pd.to_numeric(aligned_df.get('iostat_fra_mbps', 0), errors='coerce')
            other = (data.fillna(0) + redo.fillna(0) + fra.fillna(0))
            boot_mean = float(boot.dropna().mean()) if boot.notna().any() else 0.0
            other_mean = float(other.dropna().mean()) if other.notna().any() else 0.0

            # If boot is materially active and is >= 50% of the expected BV traffic, mark mismatch.
            if boot_mean >= 10 and (other_mean <= 0 or (boot_mean / max(other_mean, 1e-9)) >= 0.5):
                topology_ok = False

    if topology_ok:
        topology_score = 25
        findings.append("Storage topology appears correct")
    else:
        topology_score = 0
        findings.append("Storage topology mismatch detected")
        recommendations.append("Verify database files are on expected block volumes")

    # 4. Time coverage score (derived from actual window)
    coverage = 0
    if not aligned_df.empty and 'timestamp' in aligned_df.columns:
        ts = pd.to_datetime(aligned_df['timestamp'], errors='coerce')
        ts = ts.dropna()
        if len(ts) >= 2:
            start = ts.min()
            end = ts.max()
            expected_points = int((end - start).total_seconds() / 60) + 1  # 1-minute buckets

            # Count buckets with any OCI throughput column present
            oci_cols = [c for c in aligned_df.columns if 'VolumeWriteThroughput' in c or 'VolumeReadThroughput' in c]
            if oci_cols:
                actual_points = int(aligned_df.dropna(subset=oci_cols, how='all').shape[0])
            else:
                # Fallback: count any non-null numeric row
                actual_points = int(aligned_df.dropna(how='all').shape[0])

            coverage = min(100.0, (actual_points / expected_points) * 100) if expected_points > 0 else 0

    if coverage >= 80:
        coverage_score = 25
        findings.append(f"Time coverage {coverage:.0f}% >= 80% threshold")
    elif coverage >= 50:
        coverage_score = 15
        findings.append(f"Time coverage {coverage:.0f}% moderate (50-80%)")
        recommendations.append("Consider longer benchmark duration for better coverage")
    else:
        coverage_score = 0
        findings.append(f"Time coverage {coverage:.0f}% below 50%")
        recommendations.append("Benchmark duration too short for reliable OCI metrics")

    # Total score
    total_score = correlation_score + anomaly_score + topology_score + coverage_score

    # Grade
    if total_score >= 90:
        grade = 'A'
    elif total_score >= 75:
        grade = 'B'
    elif total_score >= 50:
        grade = 'C'
    elif total_score >= 25:
        grade = 'D'
    else:
        grade = 'F'

    # Pass/Fail
    if grade in ['A', 'B'] and critical_count == 0:
        pass_fail = 'PASS'
    elif critical_count > 0:
        # Any critical anomaly means the evidence is not trustworthy.
        # For Swingbench specifically, topology mismatch is a hard FAIL (wrong DB placement).
        pass_fail = 'FAIL' if phase.lower() == 'swingbench' else 'INCONCLUSIVE'
    elif grade == 'C':
        pass_fail = 'INCONCLUSIVE'
    else:
        pass_fail = 'FAIL'

    return EvidenceQualityReport(
        sprint=sprint,
        phase=phase,
        score=total_score,
        grade=grade,
        pass_fail=pass_fail,
        cross_layer_correlation=cross_corr,
        correlation_score=correlation_score,
        anomaly_count=len(anomalies),
        critical_anomalies=critical_count,
        anomaly_score=anomaly_score,
        topology_match=topology_ok,
        topology_score=topology_score,
        time_coverage_pct=coverage,
        coverage_score=coverage_score,
        findings=findings,
        recommendations=recommendations,
    )


def format_quality_summary(report: EvidenceQualityReport) -> str:
    """Format quality report as text summary."""
    lines = [
        f"# Evidence Quality Report: Sprint {report.sprint} - {report.phase}",
        "",
        f"**Overall Score:** {report.score}/100 (Grade {report.grade})",
        f"**Verdict:** {report.pass_fail}",
        "",
        "## Component Scores",
        "",
        f"| Component | Score | Details |",
        f"|-----------|-------|---------|",
        f"| Cross-layer Correlation | {report.correlation_score}/25 | r = {report.cross_layer_correlation:.2f} |",
        f"| Anomaly Check | {report.anomaly_score}/25 | {report.critical_anomalies} critical, {report.anomaly_count} total |",
        f"| Topology Match | {report.topology_score}/25 | {'OK' if report.topology_match else 'MISMATCH'} |",
        f"| Time Coverage | {report.coverage_score}/25 | {report.time_coverage_pct:.0f}% |",
        "",
        "## Findings",
        "",
    ]

    for f in report.findings:
        lines.append(f"- {f}")

    if report.recommendations:
        lines.extend([
            "",
            "## Recommendations",
            "",
        ])
        for r in report.recommendations:
            lines.append(f"- {r}")

    return "\n".join(lines)
