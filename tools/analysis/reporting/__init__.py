"""Report generation for correlation analysis."""

from .quality_scorer import EvidenceQualityReport, compute_evidence_quality
from .report_generator import generate_markdown_report, generate_html_report
from .consolidated_report import generate_consolidated_report

__all__ = [
    'EvidenceQualityReport',
    'compute_evidence_quality',
    'generate_markdown_report',
    'generate_html_report',
    'generate_consolidated_report',
]
