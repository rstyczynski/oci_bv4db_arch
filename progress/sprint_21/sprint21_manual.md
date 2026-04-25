# Sprint 21 Manual

Sprint 21 is Sprint 20 redo with one additional operator capability: **persist and control the mount via `/etc/fstab`**.

## Prerequisites

- OCI CLI configured locally.
- SSH access via the shared vault key.

## Step 1 - Diagnose multipath (sandbox)

```bash
KEEP_INFRA=true NAME_PREFIX=bv4db-s20-mpath ./tools/run_bv4db_multipath_diag_sprint21.sh
```

## Step 2 - Run A/B performance test (fio)

```bash
KEEP_INFRA=true NAME_PREFIX=bv4db-s20-mpath ./tools/run_bv4db_fio_multipath_ab_sprint21.sh
```

### Fio load profiles (selectable)

Supported `FIO_PROFILE` values:

- `randrw_4k` (default)
- `read_1m_bw`

```bash
KEEP_INFRA=true NAME_PREFIX=bv4db-s20-mpath \
  FIO_PROFILE=read_1m_bw FIO_RUNTIME_SEC=120 \
  FIO_NUMJOBS=4 FIO_IODEPTH=32 \
  ./tools/run_bv4db_fio_multipath_ab_sprint21.sh
```

### dd fallback

```bash
KEEP_INFRA=true NAME_PREFIX=bv4db-s20-mpath LOAD_GENERATOR=dd \
  DD_RUNTIME_SEC=600 DD_JOBS=4 DD_BS=16M \
  ./tools/run_bv4db_fio_multipath_ab_sprint21.sh
```

`dd` uses direct I/O (`oflag=direct`, `iflag=direct`) and is not a peak benchmark.

## Step 3 - fstab workflow (operator)

This is the Sprint 21 addition.

Oracle guidance for consistent device paths and fstab options:
[`fstab Options for Block Volumes Using Consistent Device Paths`](https://docs.oracle.com/en-us/iaas/Content/Block/References/fstaboptionsconsistentdevicepaths.htm)

### What the scripts do

Sprint 21 scripts maintain a tagged `/etc/fstab` entry for the sprint mountpoint (default `/mnt/sprint21`) with:

- `defaults,_netdev,nofail`

and update the **device path** depending on the mode:

- multipath: consistent device path (for example `/dev/oracleoci/oraclevdb`) or mapper path
- single-path: raw iSCSI by-path device (`/dev/disk/by-path/...-lun-*`)

### Manual: disable fstab entry (temporary)

On the instance:

```bash
sudo sed -i 's/^\\([^#].*# bv4db-sprint21\\)$/# \\1/' /etc/fstab
sudo mount -a || true
```

### Manual: enable fstab entry (after disabling)

```bash
sudo sed -i 's/^# \\(.*# bv4db-sprint21\\)$/\\1/' /etc/fstab
sudo mount -a
```

### Manual: verify

```bash
grep -n 'bv4db-sprint21' /etc/fstab || true
mount | grep -F ' /mnt/sprint21 ' || true
```

## Teardown

Same as Sprint 20: if you ran without `KEEP_INFRA=true`, teardown is automatic.
If you used `KEEP_INFRA=true`, tear down explicitly (and remove fstab entry if desired) in the next sprint task.

