# Sprint 18 Bugs

## BUG-1: Oracle Database Free lands on boot volume instead of project block volumes

**Item:** BV4DB-46
**Severity:** high
**Status:** fixed

- **Symptom**: `swingbench_oci_metrics_report.html` showed all-zero block-volume metrics even though `swingbench_iostat.json` and `swingbench_results_db.json` proved a real 900-second database workload.
- **Root cause**: `install_oracle_db_free.sh` allowed `/etc/init.d/oracle-free-23ai configure` to create the database under the default `/opt/oracle/oradata` path on the boot volume instead of the project storage layout at `/u02/oradata`, `/u03/redo`, and `/u04/fra`.
- **Fix**: Replaced the default Oracle Free configure path with explicit DBCA-based creation in [tools/install_oracle_db_free.sh](/Users/rstyczynski/projects/oci_bv4db_arch/tools/install_oracle_db_free.sh), added placement verification, added redo relocation onto `/u03/redo`, and added runner reuse controls in [tools/run_oracle_db_sprint17.sh](/Users/rstyczynski/projects/oci_bv4db_arch/tools/run_oracle_db_sprint17.sh) so Sprint 18 can rerun from the database phase without repeating FIO.
- **Verification**: `bash tests/integration/test_oracle_db_sprint18.sh` and the resumed Sprint 18 database-phase rerun on the existing host.

## BUG-2: OCI metrics reports omit the boot volume

**Item:** BV4DB-46
**Severity:** medium
**Status:** fixed

- **Symptom**: Sprint 18 OCI metrics reports only tracked the attached block volumes, so the evidence set could not show boot-volume activity even when the investigation explicitly needed to compare boot-volume versus attached-volume behavior.
- **Root cause**: The `blockvolume` metrics adapter only emitted `.volumes.*.ocid` resources from state and never added the instance boot volume OCID.
- **Fix**: Extended [oci_scaffold/resource/operate-blockvolume.sh](/Users/rstyczynski/projects/oci_bv4db_arch/oci_scaffold/resource/operate-blockvolume.sh) to include `.boot_volume.ocid`, and extended [tools/run_oracle_db_sprint17.sh](/Users/rstyczynski/projects/oci_bv4db_arch/tools/run_oracle_db_sprint17.sh) to discover and persist the boot volume before OCI metrics collection.
- **Verification**: `bash tests/integration/test_oracle_db_sprint18.sh` with `IT-76`, plus the resumed Sprint 18 Swingbench metrics collection path.
