# Sprint 22 Manual

Sprint 22 adds fstab-based mount persistence to the Sprint 20 multipath diagnostics and A/B benchmark. This manual contains ALL executable snippets needed by the operator.

## Sprint 22 Scope Clarification: HA Multipath (not throughput scaling)

Sprint 22 validates and documents **High Availability (HA)** multipath:

- **Multipath is enabled** (multiple iSCSI sessions are present and aggregated into `/dev/mapper/mpath*`).
- The filesystem is mounted on the multipath mapper device (for example `/dev/mapper/mpatha`).

Important: **this does not imply load-balanced I/O** across all paths.

With typical default dm-multipath policies (for example `path_selector "service-time 0"` and priority-based path groups), traffic often becomes **sticky**: one path carries most I/O while others stay mostly idle. In that case, multipath provides **failover/availability**, not additive throughput.

To inspect the active policy on the instance:

```bash
sudo multipath -ll mpatha || sudo multipath -ll
sudo multipathd show config | egrep -n 'path_selector|prio|path_grouping_policy|rr_min_io|rr_min_io_rq|rr_weight|failback|no_path_retry' || true
sudo multipathd show paths || true
```

Sprint 23 is intended to build on Sprint 22 by applying and documenting an explicit **load-balancing policy** (for example round-robin) and capturing evidence of path distribution during the benchmark.

### How to detect HA multipath mode (on the instance)

HA multipath is considered **active** when *all* of the following are true:

1. **Multiple iSCSI sessions exist** (typically one per portal/path):

```bash
sudo iscsiadm -m session
```

Expected output:

```bash
# You should see multiple sessions for the same IQN, for example:
tcp: [1] 169.254.2.2:3260,1 iqn.2015-12.com.oracleiaas:...
tcp: [2] 169.254.2.3:3260,1 iqn.2015-12.com.oracleiaas:...
tcp: [3] 169.254.2.4:3260,1 iqn.2015-12.com.oracleiaas:...
tcp: [4] 169.254.2.5:3260,1 iqn.2015-12.com.oracleiaas:...
tcp: [5] 169.254.2.6:3260,1 iqn.2015-12.com.oracleiaas:...
```

2. **A multipath mapper device exists** and shows multiple active paths:

```bash
sudo multipath -ll mpatha || sudo multipath -ll
sudo multipathd show paths || true
```

Expected output:

```bash
# multipath -ll should show mpatha and multiple underlying paths (sdb/sdc/...)
mpatha (3600...) dm-0 ORACLE,BlockVolume
size=... features='1 queue_if_no_path' hwhandler='0' wp=rw
|-+- policy='service-time 0' prio=1 status=active
| `- 4:0:0:1 sdb 8:16  active ready running
`-+- policy='service-time 0' prio=1 status=enabled
  `- 5:0:0:1 sdc 8:32  active ready running
  # ... more paths ...
```

3. **The filesystem mount is using the mapper device** (not a raw `/dev/sdX`):

```bash
findmnt -n -o SOURCE,FSTYPE,TARGET --target /mnt/sprint22
# Expected SOURCE: /dev/mapper/mpath* or /dev/dm-*
```

Expected output:

```bash
/dev/mapper/mpatha xfs /mnt/sprint22
```

If (1) and (2) are true but (3) shows `/dev/sdX` or a `/dev/disk/by-path/...` device, then multipath may be configured but the filesystem is **not using the multipath device** (this would not be the intended HA configuration for Sprint 22).

## Prerequisites

- OCI CLI configured locally
- SSH access via the shared vault key
- Sprint 1 shared infrastructure deployed

## Step 1 - Run Diagnostics (Sandbox)

```bash
KEEP_INFRA=true NAME_PREFIX=bv4db-s22-mpath ./tools/run_bv4db_multipath_diag_sprint22.sh
```

For smaller footprint (more likely to place):

```bash
KEEP_INFRA=true NAME_PREFIX=bv4db-s22-mpath COMPUTE_OCPUS=8 COMPUTE_MEMORY_GB=32 ./tools/run_bv4db_multipath_diag_sprint22.sh
```

## Step 2 - Run A/B Performance Test (fio)

```bash
KEEP_INFRA=true NAME_PREFIX=bv4db-s22-mpath ./tools/run_bv4db_fio_multipath_ab_sprint22.sh
```

### Fio Load Profiles

Supported `FIO_PROFILE` values:

- `randrw_4k` (default): randrw 70/30, bs=4k, numjobs=4, iodepth=32
- `read_1m_bw`: read, bs=1M, numjobs=4, iodepth=32

```bash
# Bandwidth-bound fio profile (1MiB sequential read)
KEEP_INFRA=true NAME_PREFIX=bv4db-s22-mpath \
  FIO_PROFILE=read_1m_bw FIO_RUNTIME_SEC=120 \
  FIO_NUMJOBS=4 FIO_IODEPTH=32 \
  ./tools/run_bv4db_fio_multipath_ab_sprint22.sh
```

### dd Fallback

```bash
KEEP_INFRA=true NAME_PREFIX=bv4db-s22-mpath LOAD_GENERATOR=dd \
  DD_RUNTIME_SEC=600 DD_JOBS=4 DD_BS=16M \
  ./tools/run_bv4db_fio_multipath_ab_sprint22.sh
```

## Step 3 - SSH Access to Instance

Get the latest state and connect:

```bash
STATE="$(ls -1t progress/sprint_22/state-bv4db-s22-mpath*.json 2>/dev/null | head -n 1)"
if [ -z "$STATE" ]; then
  echo "No Sprint 22 state file found. Run with KEEP_INFRA=true first."
  exit 1
fi
IP="$(jq -r '.compute.public_ip' "$STATE")"
echo "Instance IP: $IP"

SECRET_OCID="$(jq -r '.secret.ocid' progress/sprint_1/state-bv4db.json)"
TMPKEY="$(mktemp)"
chmod 600 "$TMPKEY"
oci secrets secret-bundle get \
  --secret-id "$SECRET_OCID" \
  --query 'data."secret-bundle-content".content' --raw-output \
  | base64 --decode > "$TMPKEY"

go_remote() {
  ssh -i "$TMPKEY" -o StrictHostKeyChecking=no -o ConnectTimeout=15 -o BatchMode=yes "opc@${IP}"
}

echo "Use 'go_remote' to connect to the instance"
```

## Step 4 - fstab Workflow (Operator)

This is the Sprint 22 addition. Oracle guidance for fstab options:
[fstab Options for Block Volumes Using Consistent Device Paths](https://docs.oracle.com/en-us/iaas/Content/Block/References/fstaboptionsconsistentdevicepaths.htm)

### Quick checklist: fstab + HA multipath (on the instance)

fstab entry present:

```bash
grep 'bv4db-sprint22' /etc/fstab || echo "No Sprint 22 fstab entry"
```

Expected output (example):

```bash
/dev/oracleoci/oraclevdb /mnt/sprint22 xfs defaults,_netdev,nofail 0 2 # bv4db-sprint22
```

HA multipath active (sessions + map + mount source):

```bash
sudo iscsiadm -m session
sudo multipath -ll mpatha || sudo multipath -ll
findmnt -n -o SOURCE,FSTYPE,TARGET --target /mnt/sprint22
```

Expected output:

```bash
# Multiple tcp sessions for the IQN:
tcp: [1] 169.254.2.2:3260,1 iqn.2015-12.com.oracleiaas:...
tcp: [2] 169.254.2.3:3260,1 iqn.2015-12.com.oracleiaas:...
# ... more sessions ...

# Mount uses mapper device:
/dev/mapper/mpatha xfs /mnt/sprint22
```

### What Sprint 22 fstab does (and why)

Sprint 22 uses an `/etc/fstab` entry to make the block-volume-backed filesystem **persist across reruns and reboots**.

- **`_netdev`**: tells the OS this is a “network device” mount, so boot ordering waits for networking/iSCSI.
- **`nofail`**: prevents boot failure if the volume is temporarily unavailable.
- **Tag `# bv4db-sprint22`**: makes the entry easy to find/update/remove safely without touching unrelated fstab lines.

The typical Sprint 22 entry shape is:

```bash
grep 'bv4db-sprint22' /etc/fstab || true
# Example:
# /dev/oracleoci/oraclevdb /mnt/sprint22 xfs defaults,_netdev,nofail 0 2 # bv4db-sprint22
```

Expected output:

```bash
/dev/oracleoci/oraclevdb /mnt/sprint22 xfs defaults,_netdev,nofail 0 2 # bv4db-sprint22
```

When the scripts update `/etc/fstab`, they also run `systemctl daemon-reload` and `mount -a` to refresh systemd mount units and immediately validate the entry.

### View Current fstab Entry

On the instance (after SSH):

```bash
grep 'bv4db-sprint22' /etc/fstab || echo "No Sprint 22 fstab entry"
```

Or use the management script:

```bash
sudo /tmp/bv4db_sprint22_fstab.sh show
```

### Verify Mount Status

```bash
sudo /tmp/bv4db_sprint22_fstab.sh verify --mount /mnt/sprint22
```

### Disable Multipath (Temporary via fstab)

This comments out the fstab entry and unmounts the filesystem:

```bash
sudo /tmp/bv4db_sprint22_fstab.sh disable --mount /mnt/sprint22
```

Manual equivalent:

```bash
# Comment out the fstab entry
sudo sed -i 's/^\\([^#].*# bv4db-sprint22\\)$/# \\1/' /etc/fstab

# Unmount
sudo umount /mnt/sprint22 || true

# Verify
grep -n 'bv4db-sprint22' /etc/fstab || true
mount | grep -F '/mnt/sprint22' || echo "Not mounted"
```

### Enable Multipath (After Disabling)

This uncomments the fstab entry and mounts the filesystem:

```bash
sudo /tmp/bv4db_sprint22_fstab.sh enable --mount /mnt/sprint22
```

Manual equivalent:

```bash
# Uncomment the fstab entry
sudo sed -i 's/^# \\(.*# bv4db-sprint22\\)$/\\1/' /etc/fstab

# Mount
sudo mount -a

# Verify
grep -n 'bv4db-sprint22' /etc/fstab || true
mount | grep -F '/mnt/sprint22' || echo "Not mounted"
```

### Remove fstab Entry Entirely

```bash
sudo /tmp/bv4db_sprint22_fstab.sh remove --mount /mnt/sprint22
```

### Test Reboot Persistence

To verify the mount survives a reboot:

```bash
# Verify fstab entry exists
grep 'bv4db-sprint22' /etc/fstab

# Simulate reboot (unmount + mount)
sudo umount /mnt/sprint22 || true
sudo mount -a

# Verify mount came back
mountpoint /mnt/sprint22 && echo "Mount persisted successfully"
```

## Step 5 - Switch Between Multipath and Single-Path

### Multipath Mode (Default)

fstab uses consistent device path `/dev/oracleoci/oraclevdb`:

```bash
# On the instance
grep 'bv4db-sprint22' /etc/fstab
# Expected: /dev/oracleoci/oraclevdb /mnt/sprint22 xfs defaults,_netdev,nofail 0 2 # bv4db-sprint22
```

### Single-Path Mode

To switch to single-path:

1. Disable current fstab entry:
```bash
sudo /tmp/bv4db_sprint22_fstab.sh disable --mount /mnt/sprint22
```

2. Stop multipath and logout all sessions:
```bash
sudo systemctl disable --now multipathd || true
sudo iscsiadm -m node --logout || true
```

3. Login to ONE target only (get IQN/PORT/TARGET from OCI console or state):
```bash
# Example - replace with actual values
IQN="iqn.2015-12.com.oracleiaas:..."
PORT="3260"
TARGET="169.254.2.x"

sudo iscsiadm -m node -o new -T "$IQN" -p "${TARGET}:${PORT}" || true
sudo iscsiadm -m node -T "$IQN" -p "${TARGET}:${PORT}" --login || true
```

4. Update fstab for single-path device:
```bash
# Find the by-path device
DEV="$(ls -1 /dev/disk/by-path/ip-*-iscsi-*-lun-* 2>/dev/null | head -n 1)"
echo "Single-path device: $DEV"

# Update fstab
sudo /tmp/bv4db_sprint22_fstab.sh add --device "$DEV" --mount /mnt/sprint22
```

### Switch Back to Multipath

1. Remove single-path fstab entry:
```bash
sudo /tmp/bv4db_sprint22_fstab.sh remove --mount /mnt/sprint22
sudo iscsiadm -m node --logout || true
```

2. Re-enable multipath:
```bash
sudo systemctl enable --now multipathd
```

3. Login to all targets (the A/B script does this automatically)

4. Add multipath fstab entry:
```bash
sudo /tmp/bv4db_sprint22_fstab.sh add --device /dev/oracleoci/oraclevdb --mount /mnt/sprint22
```

## Step 6 - Collect Diagnostics

On the instance:

```bash
TS="$(date -u '+%Y%m%d_%H%M%S')"
OUT="/tmp/multipath_diagnostics_${TS}.txt"

{
  echo "=== date ==="; date -u; echo
  echo "=== uname ==="; uname -a || true; echo
  echo "=== fstab (sprint 22) ==="; grep 'bv4db-sprint22' /etc/fstab || true; echo
  echo "=== systemctl status iscsid ==="; sudo systemctl status iscsid --no-pager || true; echo
  echo "=== systemctl status multipathd ==="; sudo systemctl status multipathd --no-pager || true; echo
  echo "=== iscsiadm -m session ==="; sudo iscsiadm -m session || true; echo
  echo "=== multipath -ll ==="; sudo multipath -ll || true; echo
  echo "=== lsblk ==="; lsblk -o NAME,TYPE,SIZE,MODEL,WWN,MOUNTPOINTS || true; echo
  echo "=== /dev/oracleoci ==="; ls -la /dev/oracleoci || true; echo
  echo "=== mount status ==="; mount | grep '/mnt/sprint22' || true; echo
} | tee "$OUT"

echo "Wrote: $OUT"
```

## Step 7 - Teardown

### Automatic Teardown

If you run without `KEEP_INFRA=true`, teardown happens automatically and fstab entry is removed.

### Manual Teardown

```bash
cd progress/sprint_22

export PATH="$PWD/../../oci_scaffold/do:$PWD/../../oci_scaffold/resource:$PATH"

export NAME_PREFIX="bv4db-s22-mpath"
export STATE_FILE="$PWD/state-${NAME_PREFIX}.json"
echo "=== Teardown NAME_PREFIX=$NAME_PREFIX ==="

export FORCE_DELETE=true
teardown-blockvolume.sh || true
teardown-compute.sh || true
rm -f "$STATE_FILE" || true

cd ../..
```

### Teardown by Display Name (Fallback)

If state file is missing:

```bash
COMPARTMENT_OCID="$(jq -r '.compartment.ocid' progress/sprint_1/state-bv4db.json)"

for name in bv4db-s22-mpath-instance; do
  INSTANCE_OCID="$(oci compute instance list \
    --compartment-id "$COMPARTMENT_OCID" \
    --display-name "$name" \
    --query 'data[0].id' --raw-output)"
  [ -n "$INSTANCE_OCID" ] && [ "$INSTANCE_OCID" != "null" ] || continue
  echo "Terminating $name ($INSTANCE_OCID)"
  oci compute instance terminate --instance-id "$INSTANCE_OCID" --preserve-boot-volume false --force --wait-for-state TERMINATED
done
```

## Outputs

Artifacts are written under `progress/sprint_22/`:

- `state-bv4db-s22-mpath*.json` - Instance state
- `fstab_state_*.txt` - fstab state snapshots
- `multipath_diagnostics_*.txt` - Multipath diagnostics
- `diag_multipath_*.txt` / `diag_singlepath_*.txt` - A/B diagnostics
- `fio_multipath_*.json` / `fio_singlepath_*.json` - fio results
- `fio_compare_*.md` - A/B comparison summary

## Quick Reference

| Action | Command |
|--------|---------|
| Run diagnostics | `KEEP_INFRA=true ./tools/run_bv4db_multipath_diag_sprint22.sh` |
| Run A/B test | `KEEP_INFRA=true ./tools/run_bv4db_fio_multipath_ab_sprint22.sh` |
| Show fstab entry | `sudo /tmp/bv4db_sprint22_fstab.sh show` |
| Verify mount | `sudo /tmp/bv4db_sprint22_fstab.sh verify --mount /mnt/sprint22` |
| Disable multipath | `sudo /tmp/bv4db_sprint22_fstab.sh disable --mount /mnt/sprint22` |
| Enable multipath | `sudo /tmp/bv4db_sprint22_fstab.sh enable --mount /mnt/sprint22` |
| Remove fstab entry | `sudo /tmp/bv4db_sprint22_fstab.sh remove --mount /mnt/sprint22` |
