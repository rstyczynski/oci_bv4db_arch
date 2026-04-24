# Sprint 20 - Design

Status: Approved

## Scope

- Single compute instance.
- Single UHP block volume.
- Two attachment usage modes on the guest:
  - multipath enabled
  - multipath disabled / single-path login

## Feasibility

- OCI volume attachments expose multipath target IPs for UHP iSCSI.
- Guest can enable multipath via `mpathconf` and `multipathd`.
- Guest can force single-path behavior by logging in only one target IP and stopping `multipathd`.

## Outputs

- Diagnostics artifacts for each mode.
- fio JSON results for each mode (preferred).
- dd-based results for each mode (fallback when fio is unavailable).
- Short comparison summary (`fio_compare_*.md`).

## Load generation (fio preferred, dd fallback)

- Primary generator: `fio` (randrw 70/30, bs=4k, numjobs=4, iodepth=32, time-based runtime).
- Fallback generator: `dd` when `fio` is unavailable on the guest.

dd fallback requirements:

- Use **direct I/O** (`oflag=direct`, `iflag=direct`) and ensure write durability (`conv=fdatasync`).
- Use **multiple parallel workers** (default: 4) to approximate fio concurrency.
- Each worker must use a distinct file on the mounted filesystem.
- Capture raw dd outputs and compute aggregated throughput (MB/s) for write, read, and total.

Runtime parameters (env vars):

- `DD_JOBS` (default 4)
- `DD_SIZE_GB` (default 16; per worker)
- `DD_BS` (default 16M)

## Diagnostics tools and commands

The sprint collects diagnostics from the guest for troubleshooting and evidence:

- multipath:
  - `multipath -ll`
  - `multipathd show paths`
  - `multipathd show maps`
- iSCSI:
  - `iscsiadm -m session`
  - `iscsiadm -m node`
- device mapping:
  - `lsblk -o NAME,TYPE,SIZE,MODEL,WWN,MOUNTPOINTS`
  - `ls -la /dev/oracleoci`
  - `udevadm info --query=all --name <device>` (best-effort)
  - `dmsetup ls --tree` (best-effort)
- services:
  - `systemctl status iscsid`
  - `systemctl status multipathd`

## Testing Strategy

- Test: integration
- Regression: integration

### Integration tests

- IT-1: Sprint 20 scripts exist and are executable.
- IT-2: After a run, diagnostics artifacts exist under `progress/sprint_20/`.
- IT-3: After a run, fio results exist for both modes and comparison summary exists.
