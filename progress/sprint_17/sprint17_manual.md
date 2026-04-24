# Sprint 17 - Consolidated Benchmark Manual

This manual explains how to execute the consolidated Oracle benchmark flow introduced in Sprint 17.

Compatibility note:

- `sprint17_manual.md` is the canonical file
- `sprint_manual.md` is provided as a short alias in the same directory

## What Sprint 17 runs

Sprint 17 executes two benchmark phases on one Oracle-style multi-volume topology:

1. `fio` phase with guest `iostat` and OCI metrics
2. Oracle Database Free `Swingbench` phase with guest `iostat`, OCI metrics, and AWR

## Main entry point

```bash
cd /path/to/oci_bv4db_arch
./tools/run_oracle_db_sprint17.sh
```

## Approximate timings

Sprint 17 is a long-running operation. The completed live run on `2026-04-23` used shortened `60s` FIO and `60s` Swingbench phases and still took about `35 minutes` end to end, including teardown.

Observed breakdown for that live run:

- compute and five block volumes provisioned and attached: about `9 minutes`
- Oracle-style storage layout and remote preparation: about `5 minutes`
- FIO phase with guest `iostat` and OCI metrics collection: about `10 minutes`
- Oracle Database Free install: about `6 minutes`
- Swingbench install, AWR begin/end, Swingbench run, artifact copy-back, and OCI metrics: about `11 minutes`
- teardown of compute and five block volumes: about `5 minutes`

Operator expectation for the default parameters is longer than this shortened validation run. A default `300s` Swingbench phase and longer storage exercise should be treated as roughly `45-60 minutes` wall-clock unless OCI provisioning is unusually fast.

## Main outputs

- `fio_report.html`
- `fio_oci_metrics_report.html`
- `swingbench_report.html`
- `swingbench_oci_metrics_report.html`
- `awr_report.html`
- `sprint_17_summary.md`

## Common overrides

```bash
# shorter fio phase
FIO_RUNTIME_SEC=120 ./tools/run_oracle_db_sprint17.sh

# longer Swingbench phase
SWINGBENCH_WORKLOAD_DURATION=600 ./tools/run_oracle_db_sprint17.sh

# keep the infrastructure after the run
KEEP_INFRA=true ./tools/run_oracle_db_sprint17.sh
```

## Operator expectation

Sprint 17 is substantially longer than Sprint 15 because it runs both a storage phase and a database phase on the same host. Expect:

- multi-volume provisioning and layout
- FIO phase plus metrics collection
- Oracle Database Free installation
- Swingbench phase plus AWR and metrics collection
- teardown of compute plus all five block volumes

This is a long-running automated sprint, not a quick smoke task.

## OCI Console plugin warning

In OCI Console on the instance `Management` tab, the Oracle Cloud Agent plugin `Block Volume Management` may show a warning like:

- `the plugin did not find any volume attachments for the instance`
- `open /etc/multipath.conf: permission denied`

For this project layout, that warning is expected and does not by itself indicate benchmark failure.

Reason:

- Sprint 17 uses custom `iscsi` plus `multipath` handling for the Oracle-style multi-volume layout
- the benchmark logic validates the storage path directly with attached-volume state, guest-side device discovery, `multipath`, `fio`, and `Swingbench`
- the OCI agent plugin message is not treated as the source of truth for this custom layout

Treat the run as healthy when the benchmark artifacts and runner logs show:

- block volumes attached successfully
- guest devices resolved
- `fio` and `Swingbench` completed
- artifacts copied back successfully

Additional diagnostic artifact:

- `oci_agent_multipath_diagnostics.txt`
- `oci-blockautoconfig.log`
- `oci-blockautoconfig-tail.log`

This artifact records the live host view of:

- `/etc/multipath.conf` owner and mode
- SELinux context and ACLs
- `multipathd` state
- current multipath mapping
- Oracle Cloud Agent and related process ownership
- Oracle Cloud Agent Block Volume Management plugin log output
