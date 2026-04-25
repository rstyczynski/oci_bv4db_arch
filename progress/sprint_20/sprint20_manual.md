# Sprint 20 Manual

## Prerequisites

- OCI CLI configured locally.
- SSH access via the shared vault key.

## Step 1 - Diagnose multipath (sandbox)

```bash
# Both Sprint 20 scripts share the same default NAME_PREFIX so they reuse one instance.
KEEP_INFRA=true NAME_PREFIX=bv4db-s20-mpath ./tools/run_bv4db_multipath_diag_sprint20.sh
```

In case of out of capacity error, let create smaller instance:

```bash
# smaller footprint (more likely to place)
KEEP_INFRA=true NAME_PREFIX=bv4db-s20-mpath COMPUTE_OCPUS=8 COMPUTE_MEMORY_GB=32 ./tools/run_bv4db_multipath_diag_sprint20.sh
```

## Operator - SSH access to the instance

- Run the Sprint 20 script with `KEEP_INFRA=true` so the instance is not torn down immediately.
- Extract the public IP from the newest Sprint 20 state file and connect.

```bash
STATE="$(ls -1t progress/sprint_20/state-bv4db-s20-latest.json progress/sprint_20/state-bv4db-s20-mpath-*.json 2>/dev/null | head -n 1)"
if [ -z "$STATE" ]; then
  echo "No Sprint 20 state file found. Run with KEEP_INFRA=true first, e.g."
  echo "  KEEP_INFRA=true ./tools/run_bv4db_multipath_diag_sprint20.sh"
  echo "  KEEP_INFRA=true ./tools/run_bv4db_fio_multipath_ab_sprint20.sh"
  exit 1
fi
IP="$(jq -r '.compute.public_ip' "$STATE")"

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
```

Notice go_remote helper function used to quickly connect to a just created machine.

## Diagnose multipath

Run the following commands on the instance (after SSH).

### A/B: enable vs disable multipath (operator CLI)

The Sprint 20 A/B runner automates this, but you can toggle manually to observe the difference.

Enable multipath:

Connect to the test instance:

```bash
go_remote
```

```bash
sudo multipath -ll || true
```

What to expect (example):

```text
mpatha (360bb3a0589f041ccad699df864155c40) dm-2 ORACLE,BlockVolume
size=1.5T features='4 queue_if_no_path retain_attached_hw_handler queue_mode bio' hwhandler='0' wp=rw
`-+- policy='queue-length 0' prio=1 status=active
  |- 7:0:0:2  sdb 8:16 active ready running
  |- 8:0:0:2  sdc 8:32 active ready running
  |- 9:0:0:2  sdd 8:48 active ready running
  |- 10:0:0:2 sde 8:64 active ready running
  `- 11:0:0:2 sdf 8:80 active ready running
```

Disable multipath (single-path mode):

```bash
sudo iscsiadm -m session --logout || true
sudo iscsiadm -m session || true
sudo multipath -ll 
exit
```

Expected response:

```text
iscsiadm: No active sessions.
```

### Establish iSCSI sessions (required to see paths)

You need **Sprint 20 state data** (`progress/sprint_20/state-bv4db-s20-*.json`) to find the block-volume attachment OCID, then OCI CLI to resolve `IQN/PORT/TARGETS`.

Run this on the machine where you have:

- the repo checkout (so the Sprint 20 state file exists), and
- OCI CLI configured (so `oci compute volume-attachment get` works).

Usually that is your **laptop**. You can stay logged in to the instance in another terminal and only paste the final “remote login” block there.

```bash
STATE="${STATE:-$(ls -1t progress/sprint_20/state-bv4db-s20-latest.json progress/sprint_20/state-bv4db-s20-mpath-*.json 2>/dev/null | head -n 1)}"
ATTACH_OCID="$(jq -r '.blockvolume.attachment_ocid' "$STATE")"

ATTACH_JSON="$(oci compute volume-attachment get --volume-attachment-id "$ATTACH_OCID")"
IQN="$(echo "$ATTACH_JSON" | jq -r '.data.iqn')"
PORT="$(echo "$ATTACH_JSON" | jq -r '.data.port')"
TARGETS="$(echo "$ATTACH_JSON" | jq -r '([.data.ipv4] + [.data."multipath-devices"[]?.ipv4]) | unique[]')"

echo "IQN=$IQN PORT=$PORT"
echo "$TARGETS"

# If you want to paste values manually (no OCI CLI on the instance), print a one-liner:
echo "sudo bash -s -- '$IQN' '$PORT' $TARGETS"

ssh -i "$TMPKEY" -o StrictHostKeyChecking=no -o ConnectTimeout=15 -o BatchMode=yes opc@"$IP" sudo bash -s -- "$IQN" "$PORT" $TARGETS <<'EOF'
set -euo pipefail
IQN="$1"
PORT="$2"
shift 2
TARGETS=("$@")

systemctl enable --now iscsid >/dev/null
systemctl enable --now multipathd >/dev/null 2>&1 || true

for host in "${TARGETS[@]}"; do
  iscsiadm -m node -o new -T "$IQN" -p "${host}:${PORT}" >/dev/null 2>&1 || true
  iscsiadm -m node -T "$IQN" -p "${host}:${PORT}" --op update -n node.startup -v automatic >/dev/null
  iscsiadm -m node -T "$IQN" -p "${host}:${PORT}" --login >/dev/null 2>&1 || true
done

udevadm settle
EOF
```

Multipath is enabled again. To validate, connect to the remote host:

```bash
go_remote
```

and view paths:

```bash
sudo multipath -ll || true
exit
```

with expected response:

```text
mpatha (360f36e8b85e34af0a5f419936b1281c0) dm-2 ORACLE,BlockVolume
size=1.5T features='4 queue_if_no_path retain_attached_hw_handler queue_mode bio' hwhandler='0' wp=rw
`-+- policy='queue-length 0' prio=1 status=active
  |- 7:0:0:2  sdb 8:16 active ready running
  |- 8:0:0:2  sdc 8:32 active ready running
  |- 9:0:0:2  sdd 8:48 active ready running
  |- 10:0:0:2 sde 8:64 active ready running
  `- 11:0:0:2 sdf 8:80 active ready running
```

### Single-path (disable multipath) — manual

The block above **enables multipath** (multiple iSCSI sessions + `multipathd`).  
To get a **real single-path** setup, stopping `multipathd` alone is **not enough** — you must also ensure you have **exactly one** iSCSI session and that you mount a **raw** iSCSI disk (not `/dev/mapper/mpath*`).

Run this **on the instance** (as root), after you `go_remote`:

```bash
sudo bash -s -- "$IQN" "$PORT" "$(echo "$TARGETS" | head -n 1)" <<'EOF'
set -euo pipefail
IQN="$1"
PORT="$2"
TARGET="$3"

# If mounted from previous multipath runs, unmount first.
umount -l /mnt/sprint20 2>/dev/null || true

# Logout all sessions for this IQN and wipe node DB (so we don't keep multiple sessions).
iscsiadm -m node -T "$IQN" --logout >/dev/null 2>&1 || true
iscsiadm -m node -o delete -T "$IQN" >/dev/null 2>&1 || true

# Stop multipath and flush maps.
systemctl disable --now multipathd >/dev/null 2>&1 || true
multipath -F >/dev/null 2>&1 || true

# Login to ONE target only.
iscsiadm -m node -o new -T "$IQN" -p "${TARGET}:${PORT}" >/dev/null 2>&1 || true
iscsiadm -m node -T "$IQN" -p "${TARGET}:${PORT}" --op update -n node.startup -v automatic >/dev/null
iscsiadm -m node -T "$IQN" -p "${TARGET}:${PORT}" --login >/dev/null 2>&1 || true
udevadm settle

# Resolve the real device (LUN number can vary).
DEV="$(ls -1 "/dev/disk/by-path/ip-${TARGET}:${PORT}-iscsi-${IQN}-lun-"* | head -n 1)"
echo "single-path DEV=$DEV"

# Sanity: should be exactly 1 session for this IQN.
sess_count="$(iscsiadm -m session | grep -F " $IQN " | wc -l | tr -d ' ')"
[ "${sess_count:-0}" -eq 1 ]
EOF
```

## Step 2 - Run A/B performance test (fio)

```bash
KEEP_INFRA=true NAME_PREFIX=bv4db-s20-mpath ./tools/run_bv4db_fio_multipath_ab_sprint20.sh
```

### Option 1: Run fio (preferred)

If `fio` is installed on the instance, the script will use it.

```bash
# Control fio duration (seconds)
KEEP_INFRA=true NAME_PREFIX=bv4db-s20-mpath FIO_RUNTIME_SEC=120 \
  ./tools/run_bv4db_fio_multipath_ab_sprint20.sh
```

#### Fio load profiles (selectable)

Supported `FIO_PROFILE` values (set on the laptop when invoking the top-level script):

- `randrw_4k` (default): `randrw` 70/30, `bs=4k`, `numjobs=4`, `iodepth=32`, `time_based`, `runtime=FIO_RUNTIME_SEC`
- `read_1m_bw`: `read`, `bs=1M`, `numjobs=4`, `iodepth=32`, `time_based`, `runtime=FIO_RUNTIME_SEC`

Default profile is latency/IOPS oriented (4k random R/W). You can switch to a bandwidth-bound read job:

```bash
# Bandwidth-bound fio profile (1MiB sequential read)
KEEP_INFRA=true NAME_PREFIX=bv4db-s20-mpath \
  FIO_PROFILE=read_1m_bw FIO_RUNTIME_SEC=120 \
  FIO_NUMJOBS=4 FIO_IODEPTH=32 \
  ./tools/run_bv4db_fio_multipath_ab_sprint20.sh
```

### Option 2: Run dd fallback (no fio / force dd)

If `fio` is missing (common on a fresh OL8 image), the script automatically falls back to `dd`.
You can also **force dd** explicitly:

```bash
KEEP_INFRA=true NAME_PREFIX=bv4db-s20-mpath LOAD_GENERATOR=dd \
  DD_RUNTIME_SEC=600 DD_JOBS=4 DD_BS=16M \
  ./tools/run_bv4db_fio_multipath_ab_sprint20.sh
```

**Important**: `dd` here is **not a valid peak benchmark**. It’s only a fallback load generator / sanity check.
It does **large-block sequential I/O** and does not measure IOPS/latency distribution like `fio`.
The guest script uses **direct I/O** (`oflag=direct` for write, `iflag=direct` for read), but you should still treat results as indicative only.

#### Manual load execution on the compute instance (operator)

The load generator also exists as a standalone guest script that the top-level script copies to the instance:

- local (laptop): `tools/guest/bv4db_sprint20_load.sh`
- remote (instance): `/tmp/bv4db_sprint20_load.sh`

If you are already on the instance, you can run it directly:

```bash
sudo /tmp/bv4db_sprint20_load.sh --mode fio --mnt /mnt/sprint20 --out-json /tmp/fio.json
sudo /tmp/bv4db_sprint20_load.sh --mode dd  --mnt /mnt/sprint20 --out-json /tmp/dd.json --out-txt /tmp/dd.txt
```

**How long does dd run?**

- dd supports two modes:
  - **timed mode** (recommended): set `DD_RUNTIME_SEC` and it will keep writing (then reading) for that long
  - **sized mode** (legacy): set `DD_SIZE_GB` and it will write+read that amount per job

```bash
# Timed dd run (recommended): 10 minutes write + 10 minutes read
KEEP_INFRA=true NAME_PREFIX=bv4db-s20-mpath \
  DD_RUNTIME_SEC=600 DD_JOBS=4 DD_BS=16M \
  ./tools/run_bv4db_fio_multipath_ab_sprint20.sh
```

```bash
# Timed dd run: 15 minutes write + 15 minutes read
KEEP_INFRA=true NAME_PREFIX=bv4db-s20-mpath \
  DD_RUNTIME_SEC=900 DD_JOBS=4 DD_BS=16M \
  ./tools/run_bv4db_fio_multipath_ab_sprint20.sh
```

```bash
# Smaller sized dd run (quick sanity)
KEEP_INFRA=true NAME_PREFIX=bv4db-s20-mpath \
  DD_JOBS=1 DD_SIZE_GB=1 DD_BS=16M \
  ./tools/run_bv4db_fio_multipath_ab_sprint20.sh
```

```bash
# Larger dd run (closer to sustained load)
KEEP_INFRA=true NAME_PREFIX=bv4db-s20-mpath \
  DD_JOBS=4 DD_SIZE_GB=16 DD_BS=16M \
  ./tools/run_bv4db_fio_multipath_ab_sprint20.sh
```

## Step 3 - Teardown

- If you ran without `KEEP_INFRA=true`, teardown happens automatically at script end.
- If you used `KEEP_INFRA=true`, you must teardown explicitly.

### Teardown (delete ALL Sprint 20 instances / volumes)

Current default `NAME_PREFIX` is shared (`bv4db-s20-mpath`) so both scripts reuse one instance.

Older runs may still exist under the previous prefixes:

- `bv4db-s20-mpath-diag`
- `bv4db-s20-mpath-ab`

To delete **everything** (current + legacy), run teardown for each prefix.

```bash
cd progress/sprint_20

export PATH="$PWD/../../oci_scaffold/do:$PWD/../../oci_scaffold/resource:$PATH"

for p in bv4db-s20-mpath bv4db-s20-mpath-diag bv4db-s20-mpath-ab; do
  export NAME_PREFIX="$p"
  export STATE_FILE="$PWD/state-${NAME_PREFIX}.json"
  echo "=== Teardown NAME_PREFIX=$NAME_PREFIX (STATE_FILE=$STATE_FILE) ==="
  export FORCE_DELETE=true
  teardown-blockvolume.sh || true
  teardown-compute.sh || true
  rm -f "$STATE_FILE" || true
done
cd ../..
```

If teardown prints `Compute instance: nothing to delete` but the instance is still running, the state file likely does not contain `.compute.ocid` or `.compute.created=true`. In that case, terminate by display name:

```bash
COMPARTMENT_OCID="$(jq -r '.compartment.ocid' ../sprint_1/state-bv4db.json)"

for name in bv4db-s20-mpath-instance bv4db-s20-mpath-diag-instance bv4db-s20-mpath-ab-instance; do
  INSTANCE_OCID="$(oci compute instance list \
    --compartment-id "$COMPARTMENT_OCID" \
    --display-name "$name" \
    --query 'data[0].id' --raw-output)"
  [ -n "$INSTANCE_OCID" ] && [ "$INSTANCE_OCID" != "null" ] || continue
  echo "Terminating $name ($INSTANCE_OCID)"
  oci compute instance terminate --instance-id "$INSTANCE_OCID" --preserve-boot-volume false --force --wait-for-state TERMINATED
done
```

### Cheat sheet

What to expect in a healthy multipath run:

- `systemctl status iscsid`: **active (running)**
- `systemctl status multipathd`: **active (running)** in multipath mode (may be inactive in single-path mode)
- `iscsiadm -m session`: **multiple sessions** for multipath (more than 1); **one session** for single-path
- `multipath -ll`: at least one **mpath** map with **multiple active paths**
- `multipathd show paths`: multiple paths in **active/ready** state

```bash
sudo systemctl status iscsid --no-pager || true
sudo systemctl status multipathd --no-pager || true

sudo iscsiadm -m session || true
sudo iscsiadm -m node || true

sudo multipath -ll || true
sudo multipathd show paths || true
sudo multipathd show maps || true
```

### Device mapping evidence

```bash
ls -la /dev/oracleoci || true
lsblk -o NAME,TYPE,SIZE,MODEL,WWN,MOUNTPOINTS || true

sudo dmsetup ls --tree || true

DEV="$(readlink -f /dev/oracleoci/oraclevdb 2>/dev/null || true)"
echo "DEV=$DEV"
if [ -n "${DEV:-}" ] && [ -b "$DEV" ]; then
  sudo udevadm info --query=all --name "$DEV" || true
fi
```

### Capture everything to a file (recommended)

```bash
TS="$(date -u '+%Y%m%d_%H%M%S')"
OUT="/tmp/multipath_diagnostics_${TS}.txt"

{
  echo "=== date ==="; date -u; echo
  echo "=== uname ==="; uname -a || true; echo
  echo "=== systemctl status iscsid ==="; sudo systemctl status iscsid --no-pager || true; echo
  echo "=== systemctl status multipathd ==="; sudo systemctl status multipathd --no-pager || true; echo
  echo "=== iscsiadm -m session ==="; sudo iscsiadm -m session || true; echo
  echo "=== iscsiadm -m node ==="; sudo iscsiadm -m node || true; echo
  echo "=== multipath -ll ==="; sudo multipath -ll || true; echo
  echo "=== multipathd show paths ==="; sudo multipathd show paths || true; echo
  echo "=== multipathd show maps ==="; sudo multipathd show maps || true; echo
  echo "=== lsblk ==="; lsblk -o NAME,TYPE,SIZE,MODEL,WWN,MOUNTPOINTS || true; echo
  echo "=== dmsetup ls --tree ==="; sudo dmsetup ls --tree || true; echo
  echo "=== /dev/oracleoci ==="; ls -la /dev/oracleoci || true; echo
  echo "=== udevadm info (oracleoci block device) ==="
  DEV="$(readlink -f /dev/oracleoci/oraclevdb 2>/dev/null || true)"
  echo "DEV=$DEV"
  if [ -n "${DEV:-}" ] && [ -b "$DEV" ]; then
    sudo udevadm info --query=all --name "$DEV" || true
  fi
} | tee "$OUT"

echo "Wrote: $OUT"
```

## Outputs

Artifacts are written under `progress/sprint_20/`.
