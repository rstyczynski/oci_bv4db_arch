# Sprint 16 Summary

Sprint 16 is retrospectively failed.

It uses archived evidence from Sprint 10, Sprint 15, and Sprint 17 to answer two questions:

1. what `fio` alone can prove about the OCI block volume architecture
2. what Oracle Database Free `Swingbench` plus AWR adds beyond `fio`

Main outcome:

- `fio` remains the best storage-headroom and isolation proof
- `Swingbench` plus AWR is required to explain database-visible bottlenecks such as commit latency, DB CPU share, and the read-versus-write profile seen by Oracle itself
- Sprint 17 is the first run in the repository where `fio`, guest `iostat`, OCI metrics, `Swingbench`, and AWR can be read together as one evidence package

Failure note:

- Sprint 16 accepted Sprint 17 Swingbench correlation evidence even though the archived workload data already showed the wrong storage path
- guest `iostat` did not sustain the expected traffic on attached data block volumes during Swingbench, while the boot device showed strong activity
- archived OCI metrics for the attached block volumes during Swingbench were nearly all zero at the per-volume level
- because Sprint 16 did not treat that contradiction as a failure, it overstated the validity of its storage-to-database correlation conclusions

Primary analysis artifact:

- `sprint_16_correlation.md`

Source artifact anchors:

- Sprint 10 `oci_performance_tier_comparison.md`
- Sprint 15 `swingbench_results_db.json`, `awr_report.html`
- Sprint 17 `fio_results.json`, `fio_iostat.json`, `fio_oci_metrics_report.md`, `swingbench_results_db.json`, `swingbench_iostat.json`, `swingbench_oci_metrics_report.md`, `awr_report.html`
