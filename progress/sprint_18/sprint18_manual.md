# Sprint 18 - 900s Mirror Run Manual

Sprint 18 is a direct rerun of Sprint 17 with longer benchmark windows.

## Main entry point

```bash
./tools/run_oracle_db_sprint18.sh
```

## Default benchmark durations

- `fio`: `900` seconds
- `Swingbench`: `900` seconds

## Expected outputs

- `fio_report.html`
- `fio_oci_metrics_report.html`
- `swingbench_report.html`
- `swingbench_oci_metrics_report.html`
- `awr_report.html`
- `sprint_18_summary.md`

## Final Sprint 18 result

The completed `900s` Swingbench rerun archived:

- `1319532` completed transactions
- `0` failed transactions in the archived result set
- `1466.15` average TPS
- AWR snapshots `1 -> 2`

## OCI Console plugin warning

In OCI Console on the instance `Management` tab, the Oracle Cloud Agent plugin `Block Volume Management` may show a warning like:

- `the plugin did not find any volume attachments for the instance`
- `open /etc/multipath.conf: permission denied`

For Sprint 18 this warning is expected and is not used as the benchmark health signal.

Reason:

- Sprint 18 mirrors Sprint 17 and uses the same custom `iscsi` plus `multipath` Oracle-style storage layout
- OCI metrics evidence now includes the boot volume alongside the attached Oracle data, redo, and FRA block volumes so the report can make boot-volume activity explicit when it appears
- the benchmark validates storage behavior through runner logs, attached-volume state, guest device discovery, `fio`, `Swingbench`, OCI metrics, and AWR
- the OCI agent plugin can misreport attachment visibility for this custom guest-side layout

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
