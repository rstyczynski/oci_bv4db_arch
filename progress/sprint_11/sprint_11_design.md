# Sprint 11 Design

Status: tested

Mode:

- `YOLO`

Scope:

- introduce an `operate-*` command in `oci_scaffold`
- use it to collect OCI metrics for compute, block volume, and network resources
- drive metric selection from a definition file by resource class
- refactor metrics collection so generic code stays shared and resource-specific logic stays in resource-level adapters
- execute a `5`-minute Oracle-style load to produce real monitoring data
- generate a report artifact from the collected metrics

Design choices:

- implement metrics collection as a generic `operate-metrics.sh` command
- after the first implementation, reopen Sprint 11 to move class-specific resource resolution into dedicated adapter scripts
- use Markdown for the first generated report artifact
- use Sprint 10 Balanced single-volume Oracle layout for the `5`-minute load because it produces one compute, one block volume, and one primary VNIC with clean post-test resource mapping
- collect compute metrics from `oci_computeagent`, block volume metrics from `oci_blockstore`, and VNIC metrics from `oci_vcn`
