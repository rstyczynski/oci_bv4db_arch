# Sprint 2 Manual — Multipath (UHP iSCSI) Configuration

Sprint 2 is the first sprint that configures **UHP iSCSI multipath** in a repeatable “operator-safe” way.

This manual explains how to proceed with the Sprint 2 multipath configuration and how to verify it.

## Main entry point (recommended)

Sprint 2 is executed via:

```bash
./tools/run_bv_fio_perf.sh
```

This script provisions the instance + UHP block volume, performs guest iSCSI + multipath configuration, resolves the stable multipath device path, runs fio, collects artifacts, and tears down.

## What “proper multipath” means in Sprint 2

Sprint 2 treats multipath as correct only when:

- all iSCSI target IP paths are logged in (primary + `multipath-devices`)
- `multipathd` is enabled and running
- the block volume is accessible as a **multipath mapper device**, typically `/dev/mapper/mpatha`

The runner uses the Oracle-provided device symlink and then resolves it to an `mpath` device when available:

- expected device path: `/dev/oracleoci/oraclevdb`
- resolved multipath device: `/dev/mapper/mpatha` (or similar)

## What the script does on the guest (reference)

The script configures iSCSI sessions and enables multipath:

- `systemctl enable --now iscsid`
- `mpathconf --enable --with_multipathd y`
- `systemctl enable --now multipathd`
- for each target IP:
  - create node (if needed)
  - set node startup to automatic
  - login
- wait for `/dev/oracleoci/oraclevdb` to appear
- if it fails, it prints diagnostics:
  - `iscsiadm -m session`
  - `multipath -ll`
  - `ls -l /dev/oracleoci`

## Manual verification steps (if you need to debug)

On the instance (as root / sudo):

### 1) Confirm iSCSI sessions

```bash
sudo iscsiadm -m session
```

You should see **multiple sessions** (one per path).

### 2) Confirm multipath services

```bash
sudo systemctl status multipathd --no-pager
sudo systemctl status iscsid --no-pager
```

Both should be **active (running)**.

### 3) Confirm multipath device exists

```bash
ls -l /dev/oracleoci/oraclevdb
sudo lsblk -o NAME,TYPE,SIZE,MODEL | head -n 50
sudo multipath -ll
```

Expected:

- `/dev/oracleoci/oraclevdb` exists
- `multipath -ll` shows an `mpath*` device with multiple paths
- `lsblk` shows the device type `mpath` for the mapper device

### 4) Confirm the benchmark uses the mapper device

Sprint 2 resolves the benchmark device using:

- `readlink -f /dev/oracleoci/oraclevdb`
- then it checks for `lsblk ... TYPE == mpath` and returns the mapper device

So the benchmark should run on `/dev/mapper/mpath*` when multipath is correctly configured.

## Common failure modes

### Device path never appears

Symptom:

- the script times out waiting for `/dev/oracleoci/oraclevdb`

Actions:

- verify iSCSI sessions: `sudo iscsiadm -m session`
- verify multipath: `sudo multipath -ll`
- run udev settle: `sudo udevadm settle`

### Only a single path is logged in

Symptom:

- `iscsiadm -m session` shows only one session

Actions:

- confirm the OCI attachment exposes `multipath-devices` for the volume attachment
- re-login to missing target IPs

## Outputs

Sprint 2 artifacts are stored under `progress/sprint_2/` after completion, including:

- fio JSON outputs (perf sequential/random)
- `fio_analysis.md`
- archived teardown state JSON
