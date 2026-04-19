# Sprint 11 Implementation

Status: tested

YOLO decision log:

- Ambiguity: whether the first `operate-*` command should be resource-specific or generic.
  Assumption: implement a generic `operate-metrics.sh` command first.
  Rationale: the requirement is cross-resource metrics collection and reporting, so a generic metrics operator is the cleanest first proof of the `operate-*` lifecycle class.
  Risk: low.

- Bug found after initial implementation: `operate-metrics.sh` sourced resource-specific files directly, which inverted the intended `operate-*` ownership model.
  Fix: refactor to real `operate-compute.sh`, `operate-blockvolume.sh`, and `operate-network.sh` entry points that each source shared logic from `do/shared-metrics.sh`, while `operate-metrics.sh` invokes those resource scripts as external commands.
  Risk: low.

- Ambiguity: whether to generate HTML or Markdown first.
  Assumption: generate Markdown first and keep HTML as later enhancement.
  Rationale: Markdown keeps the implementation small while still producing a usable report artifact.
  Risk: low.

Execution summary:

- implemented `oci_scaffold/resource/operate-metrics.sh` as the first `operate-*` command
- reopened Sprint 11 to complete `BV4DB-31`
- moved generic metrics helper logic into `oci_scaffold/do/shared-metrics.sh`
- implemented resource-owned `operate-*` scripts:
  - `oci_scaffold/resource/operate-compute.sh`
  - `oci_scaffold/resource/operate-blockvolume.sh`
  - `oci_scaffold/resource/operate-network.sh`
- recorded the benchmark `test_window` in the Oracle runner state
- executed a `5`-minute Balanced single-volume Oracle-style load to produce real OCI Monitoring data
- synthesized a metrics collection state from the archived run state and archived block volume state
- collected compute metrics from `oci_computeagent`
- collected block volume metrics from `oci_blockstore`
- collected network metrics from `oci_vcn` for the primary VNIC
- generated Markdown report and raw JSON artifact

Selected metrics:

- compute: `CpuUtilization`, `MemoryUtilization`, `DiskBytesRead`, `DiskBytesWritten`
- block volume: `VolumeReadThroughput`, `VolumeWriteThroughput`, `VolumeReadOps`, `VolumeWriteOps`
- network: `VnicFromNetworkBytes`, `VnicToNetworkBytes`, `VnicEgressDropsSecurityList`, `VnicIngressDropsSecurityList`

Practical result:

- the `operate-*` lifecycle class is justified for read-only post-test actions
- a definition file per resource class is sufficient to control metric selection without hardcoding the report content in the operator
- the main operator is now generic enough to delegate resource-class behavior to resource-owned `operate-*` scripts
- Markdown is already useful for the first report generation pass; HTML can remain a later enhancement
