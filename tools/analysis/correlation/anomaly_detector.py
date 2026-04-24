"""Anomaly detection for benchmark evidence."""

from dataclasses import dataclass, field
from typing import List, Callable, Dict, Any, Optional
import pandas as pd
import numpy as np


@dataclass
class AnomalyRule:
    """Definition of an anomaly detection rule."""
    id: str
    name: str
    description: str
    severity: str  # 'critical', 'warning', 'info'
    check_fn: Callable[[pd.DataFrame, Dict[str, Any]], bool]
    message_fn: Callable[[pd.DataFrame, Dict[str, Any]], str]


@dataclass
class Anomaly:
    """Detected anomaly instance."""
    rule_id: str
    rule_name: str
    severity: str
    description: str
    message: str
    details: Dict[str, Any] = field(default_factory=dict)


class AnomalyDetector:
    """Rule-based anomaly detector for benchmark evidence."""

    def __init__(self):
        self.rules: List[AnomalyRule] = []
        self._register_default_rules()

    def _register_default_rules(self):
        """Register default anomaly detection rules."""

        # R1: iostat active but OCI metrics zero
        self.rules.append(AnomalyRule(
            id='R1',
            name='iostat_oci_mismatch',
            description='Guest iostat shows activity but OCI block volume metrics are zero',
            severity='critical',
            check_fn=self._check_r1_iostat_oci_mismatch,
            message_fn=self._msg_r1
        ))

        # R2: FIO topology mismatch
        self.rules.append(AnomalyRule(
            id='R2',
            name='fio_topology_mismatch',
            description='FIO target device does not match iostat active devices',
            severity='critical',
            check_fn=self._check_r2_fio_topology,
            message_fn=self._msg_r2
        ))

        # R3: Swingbench TPS but no block volume I/O
        self.rules.append(AnomalyRule(
            id='R3',
            name='swingbench_no_bv_io',
            description='Swingbench shows stable TPS but block volume OCI metrics are zero',
            severity='critical',
            check_fn=self._check_r3_swingbench_bv,
            message_fn=self._msg_r3
        ))

        # R4: Redo placement defect
        self.rules.append(AnomalyRule(
            id='R4',
            name='redo_placement_defect',
            description='AWR shows redo activity but redo volume OCI metrics zero',
            severity='critical',
            check_fn=self._check_r4_redo_placement,
            message_fn=self._msg_r4
        ))

        # R5: Low cross-layer correlation
        self.rules.append(AnomalyRule(
            id='R5',
            name='low_correlation',
            description='Cross-layer correlation below 0.5 threshold',
            severity='warning',
            check_fn=self._check_r5_low_correlation,
            message_fn=self._msg_r5
        ))

        # R6: Swingbench boot-volume dominance (DB files likely on boot volume)
        self.rules.append(AnomalyRule(
            id='R6',
            name='swingbench_boot_dominant_io',
            description='Swingbench I/O is dominated by boot volume activity (likely wrong DB file placement)',
            severity='critical',
            check_fn=self._check_r6_swingbench_boot_dominant,
            message_fn=self._msg_r6
        ))

    def detect(
        self,
        df: pd.DataFrame,
        context: Dict[str, Any] = None
    ) -> List[Anomaly]:
        """
        Run all rules and return detected anomalies.

        Args:
            df: Data DataFrame
            context: Additional context dict (correlation results, etc.)

        Returns:
            List of detected Anomaly instances
        """
        context = context or {}
        anomalies = []

        for rule in self.rules:
            try:
                if rule.check_fn(df, context):
                    anomaly = Anomaly(
                        rule_id=rule.id,
                        rule_name=rule.name,
                        severity=rule.severity,
                        description=rule.description,
                        message=rule.message_fn(df, context),
                    )
                    anomalies.append(anomaly)
            except Exception as e:
                # Rule not applicable or data missing
                pass

        return anomalies

    def detect_all(
        self,
        df: pd.DataFrame,
        context: Dict[str, Any] = None
    ) -> Dict[str, Any]:
        """
        Run detection and return summary.

        Returns:
            Dict with 'anomalies', 'critical_count', 'warning_count', etc.
        """
        anomalies = self.detect(df, context)

        critical = [a for a in anomalies if a.severity == 'critical']
        warnings = [a for a in anomalies if a.severity == 'warning']
        info = [a for a in anomalies if a.severity == 'info']

        return {
            'anomalies': anomalies,
            'total_count': len(anomalies),
            'critical_count': len(critical),
            'warning_count': len(warnings),
            'info_count': len(info),
            'has_critical': len(critical) > 0,
        }

    # Rule implementations

    def _check_r1_iostat_oci_mismatch(
        self, df: pd.DataFrame, ctx: Dict
    ) -> bool:
        """Check if iostat shows activity but OCI metrics are near-zero."""
        iostat_col = None
        oci_col = None

        for col in df.columns:
            if 'iostat' in col.lower() and 'write' in col.lower():
                iostat_col = col
            if 'volumewrite' in col.lower() or 'oci_write' in col.lower():
                oci_col = col

        if not iostat_col or not oci_col:
            return False

        iostat_mean = df[iostat_col].mean()
        oci_mean = df[oci_col].mean()

        # iostat > 10 MB/s but OCI < 1 MB/s
        return iostat_mean > 10 and oci_mean < 1

    def _msg_r1(self, df: pd.DataFrame, ctx: Dict) -> str:
        iostat_col = [c for c in df.columns if 'iostat' in c.lower() and 'write' in c.lower()]
        oci_cols = [c for c in df.columns if 'volumewrite' in c.lower() or 'oci_write' in c.lower()]

        iostat_val = df[iostat_col[0]].mean() if iostat_col else 0

        # Find which OCI devices have zero throughput (unique names only)
        zero_devices = set()
        for col in oci_cols:
            val = df[col].mean()
            if val < 1:
                # Extract device name from column like "data1_VolumeWriteThroughput"
                device = col.split('_')[0] if '_' in col else col
                zero_devices.add(device)

        oci_col_name = ctx.get('oci_col', oci_cols[0] if oci_cols else 'unknown')
        oci_val = df[oci_col_name].mean() if oci_col_name in df.columns else 0

        zero_devices = sorted(zero_devices)
        devices_str = ', '.join(zero_devices[:4]) if zero_devices else 'unknown'
        if len(zero_devices) > 4:
            devices_str += f' (+{len(zero_devices)-4} more)'

        return f"iostat avg {iostat_val:.1f} MB/s but OCI [{devices_str}] avg {oci_val:.2f} MB/s"

    def _check_r2_fio_topology(
        self, df: pd.DataFrame, ctx: Dict
    ) -> bool:
        """Check if FIO target matches iostat active devices."""
        # This requires topology metadata from context
        expected_devices = ctx.get('expected_devices', [])
        active_devices = ctx.get('active_devices', [])

        if not expected_devices or not active_devices:
            return False

        return set(expected_devices) != set(active_devices)

    def _msg_r2(self, df: pd.DataFrame, ctx: Dict) -> str:
        return "FIO targeting different devices than iostat observed"

    def _check_r3_swingbench_bv(
        self, df: pd.DataFrame, ctx: Dict
    ) -> bool:
        """Check if Swingbench has TPS but block volumes show no I/O."""
        tps = ctx.get('avg_tps', 0)
        if tps < 100:
            return False

    def _check_r6_swingbench_boot_dominant(self, df: pd.DataFrame, ctx: Dict) -> bool:
        """
        Check if Swingbench phase shows boot I/O dominating expected data/redo/fra I/O.

        This is a topology correctness defect: DB files were likely created under /opt/oracle/oradata
        or otherwise placed on the boot volume instead of /u02,/u03,/u04.
        """
        phase = (ctx.get('phase') or '').lower()
        if phase != 'swingbench':
            return False

        boot_col = None
        # Accept either iostat_boot_mbps (preferred) or boot_* aggregates from aligned frame.
        for c in ['iostat_boot_mbps', 'boot_read_mbps', 'boot_write_mbps']:
            if c in df.columns:
                boot_col = c
                break
        if boot_col is None:
            return False

        # Compute boot total MB/s
        if boot_col == 'iostat_boot_mbps':
            boot = pd.to_numeric(df[boot_col], errors='coerce')
        else:
            # fallback: sum read+write if present
            boot = pd.to_numeric(df.get('boot_read_mbps', 0), errors='coerce') + pd.to_numeric(df.get('boot_write_mbps', 0), errors='coerce')

        data = pd.to_numeric(df.get('iostat_data_mbps', 0), errors='coerce')
        redo = pd.to_numeric(df.get('iostat_redo_mbps', 0), errors='coerce')
        fra = pd.to_numeric(df.get('iostat_fra_mbps', 0), errors='coerce')
        other = (data.fillna(0) + redo.fillna(0) + fra.fillna(0))

        boot_mean = float(boot.dropna().mean()) if boot.notna().any() else 0.0
        other_mean = float(other.dropna().mean()) if other.notna().any() else 0.0

        # Trigger if boot is a material part of the throughput and dominates other BVs.
        # (Thresholds chosen to avoid false positives on tiny/noisy runs.)
        if boot_mean < 10:
            return False
        if other_mean <= 0:
            return True
        return (boot_mean / other_mean) >= 0.5

    def _msg_r6(self, df: pd.DataFrame, ctx: Dict) -> str:
        boot = pd.to_numeric(df.get('iostat_boot_mbps', np.nan), errors='coerce')
        data = pd.to_numeric(df.get('iostat_data_mbps', np.nan), errors='coerce')
        redo = pd.to_numeric(df.get('iostat_redo_mbps', np.nan), errors='coerce')
        fra = pd.to_numeric(df.get('iostat_fra_mbps', np.nan), errors='coerce')
        boot_mean = float(boot.dropna().mean()) if boot.notna().any() else 0.0
        other_mean = float((data.fillna(0) + redo.fillna(0) + fra.fillna(0)).mean()) if len(df) else 0.0
        ratio = (boot_mean / other_mean) if other_mean > 0 else float('inf')
        return f"Boot throughput dominates: boot={boot_mean:.1f} MB/s vs data+redo+fra={other_mean:.1f} MB/s (ratio={ratio:.2f}). Likely DB files on boot volume."

        # Check for block volume write activity
        bv_cols = [c for c in df.columns
                   if ('data' in c.lower() or 'redo' in c.lower())
                   and 'write' in c.lower()]

        if not bv_cols:
            return False

        total_bv_write = sum(df[c].mean() for c in bv_cols)
        return total_bv_write < 1  # Less than 1 MB/s total

    def _msg_r3(self, df: pd.DataFrame, ctx: Dict) -> str:
        tps = ctx.get('avg_tps', 0)

        # Find which block volume devices are idle
        bv_cols = [c for c in df.columns
                   if ('data' in c.lower() or 'redo' in c.lower() or 'fra' in c.lower())
                   and 'write' in c.lower()]

        idle_devices = []
        for col in bv_cols:
            val = df[col].mean()
            if val < 1:
                device = col.split('_')[0] if '_' in col else col
                if device not in idle_devices:
                    idle_devices.append(device)

        devices_str = ', '.join(idle_devices[:4]) if idle_devices else 'data/redo volumes'

        return f"Swingbench TPS {tps:.0f} but [{devices_str}] show no I/O (< 1 MB/s)"

    def _check_r4_redo_placement(
        self, df: pd.DataFrame, ctx: Dict
    ) -> bool:
        """Check if AWR shows redo but redo volumes are idle."""
        redo_size_gb = ctx.get('awr_redo_size_gb', 0)
        if redo_size_gb < 0.1:
            return False

        # Check redo volume activity
        redo_cols = [c for c in df.columns
                     if 'redo' in c.lower() and 'write' in c.lower()]

        if not redo_cols:
            return False

        redo_write = sum(df[c].mean() for c in redo_cols)
        return redo_write < 0.5  # Less than 0.5 MB/s

    def _msg_r4(self, df: pd.DataFrame, ctx: Dict) -> str:
        redo_gb = ctx.get('awr_redo_size_gb', 0)
        return f"AWR redo size {redo_gb:.2f} GB but redo volumes show no writes"

    def _check_r5_low_correlation(
        self, df: pd.DataFrame, ctx: Dict
    ) -> bool:
        """Check if cross-layer correlation is below threshold."""
        pearson_r = ctx.get('pearson_r')
        if pearson_r is None or np.isnan(pearson_r):
            return False

        return abs(pearson_r) < 0.5

    def _msg_r5(self, df: pd.DataFrame, ctx: Dict) -> str:
        pearson_r = ctx.get('pearson_r', 0)
        return f"Cross-layer correlation {pearson_r:.2f} below 0.5 threshold"
