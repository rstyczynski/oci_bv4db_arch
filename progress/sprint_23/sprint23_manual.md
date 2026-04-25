# Sprint 23 Manual

Sprint 23 is a copy of Sprint 22 with one key difference:

- Sprint 22 validates **HA multipath** (correct aggregation + correct mount source).
- Sprint 23 additionally applies an explicit dm-multipath **load-balancing** configuration (for example round-robin) and collects evidence of per-path I/O distribution during the benchmark window.

This manual contains ALL executable snippets needed by the operator.

## Prerequisites

- OCI CLI configured locally
- SSH access via the shared vault key
- Sprint 1 shared infrastructure deployed

## Step 1 - Run Diagnostics (Sandbox)

```bash
KEEP_INFRA=true NAME_PREFIX=bv4db-s23-mpath ./tools/run_bv4db_multipath_diag_sprint23.sh
```

For smaller footprint (more likely to place):

```bash
KEEP_INFRA=true NAME_PREFIX=bv4db-s23-mpath COMPUTE_OCPUS=8 COMPUTE_MEMORY_GB=32 ./tools/run_bv4db_multipath_diag_sprint23.sh
```

## Step 2 - Run A/B Performance Test (fio)

Default: enable dm-multipath load balancing for the multipath phase.

```bash
KEEP_INFRA=true NAME_PREFIX=bv4db-s23-mpath ./tools/run_bv4db_fio_multipath_ab_sprint23.sh
```

## Step 3 - SSH Access to Instance

Get the latest state and connect:

```bash
STATE="$(ls -1t progress/sprint_23/state-bv4db-s23-mpath*.json 2>/dev/null | head -n 1)"
if [ -z "$STATE" ]; then
  echo "No Sprint 23 state file found. Run with KEEP_INFRA=true first."
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

## Quick checklist: fstab + HA multipath (on the instance)

Run this after connecting to the instance (after `go_remote`).

fstab entry present:

```bash
grep 'bv4db-sprint23' /etc/fstab || echo "No Sprint 23 fstab entry"
```

Expected output (example):

```bash
/dev/oracleoci/oraclevdb /mnt/sprint23 xfs defaults,_netdev,nofail 0 2 # bv4db-sprint23
```

HA multipath active (sessions + map + mount source):

```bash
sudo iscsiadm -m session
sudo multipath -ll mpatha || sudo multipath -ll
findmnt -n -o SOURCE,FSTYPE,TARGET --target /mnt/sprint23
```

Expected output:

```bash
# Multiple tcp sessions for the IQN:
tcp: [1] 169.254.2.2:3260,1 iqn.2015-12.com.oracleiaas:...
tcp: [2] 169.254.2.3:3260,1 iqn.2015-12.com.oracleiaas:...
# ... more sessions ...

# Mount uses mapper device (name may be mpatha or WWID when user_friendly_names=no):
/dev/mapper/mpatha xfs /mnt/sprint23
# Example with WWID map name:
# /dev/mapper/360debd75f3ad4e8d93bb56045cd9cb1d xfs /mnt/sprint23
```

### Fio Load Profiles

Supported `FIO_PROFILE` values:

- `randrw_4k` (default): randrw 70/30, bs=4k, numjobs=4, iodepth=32
- `read_1m_bw`: read, bs=1M, numjobs=4, iodepth=32

```bash
KEEP_INFRA=true NAME_PREFIX=bv4db-s23-mpath \
  FIO_PROFILE=read_1m_bw FIO_RUNTIME_SEC=300 \
  ./tools/run_bv4db_fio_multipath_ab_sprint23.sh
```

### Disable Load Balancing (HA baseline only)

```bash
KEEP_INFRA=true NAME_PREFIX=bv4db-s23-mpath MULTIPATH_LB_ENABLE=false \
  ./tools/run_bv4db_fio_multipath_ab_sprint23.sh
```

## Step 4 - Inspect Multipath Policy (on the instance)

```bash
sudo multipath -ll mpatha || sudo multipath -ll
sudo multipathd show config | egrep -n 'path_selector|prio|path_grouping_policy|rr_min_io|rr_min_io_rq|rr_weight|failback|no_path_retry' || true
sudo multipathd show paths || true
```

## Step 5 - fstab Workflow (Operator)

Same workflow as Sprint 22, but with tag `bv4db-sprint23` and mountpoint `/mnt/sprint23`.

On the instance (after SSH):

```bash
sudo /tmp/bv4db_sprint23_fstab.sh show
sudo /tmp/bv4db_sprint23_fstab.sh verify --mount /mnt/sprint23
```

## Step 6 - Teardown

### Automatic Teardown

If you run without `KEEP_INFRA=true`, teardown happens automatically at the end of the run.

### Manual Teardown (Preferred)

Run from the Sprint 23 progress directory so `STATE_FILE` resolves correctly:

```bash
cd progress/sprint_23

export PATH="$PWD/../../oci_scaffold/do:$PWD/../../oci_scaffold/resource:$PATH"

export NAME_PREFIX="bv4db-s23-mpath"
export STATE_FILE="$PWD/state-${NAME_PREFIX}.json"
echo "=== Teardown NAME_PREFIX=$NAME_PREFIX ==="

export FORCE_DELETE=true
teardown-blockvolume.sh || true
teardown-compute.sh || true
rm -f "$STATE_FILE" || true

cd ../..
```

### Teardown by Display Name (Fallback)

If the state file is missing:

```bash
COMPARTMENT_OCID="$(jq -r '.compartment.ocid' progress/sprint_1/state-bv4db.json)"

for name in bv4db-s23-mpath-instance; do
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

Artifacts are written under `progress/sprint_23/`:

- `state-bv4db-s23-mpath*.json` - Instance state
- `fstab_state_*.txt` - fstab state snapshots
- `diag_multipath_*.txt` / `diag_singlepath_*.txt` - A/B diagnostics
- `cfg_multipath_pre/post_*.txt` / `cfg_singlepath_pre/post_*.txt` - “before/after” config snapshots
- `fio_multipath_*.json` / `fio_singlepath_*.json` - fio results
- `fio_multipath_*.txt` / `fio_singlepath_*.txt` - timestamped fio progress (if enabled)
- `iostat_multipath_*.txt` / `iostat_singlepath_*.txt` - bounded `iostat -x` during fio (if `IOSTAT_ENABLE=true`)
- `fio_compare_*.md` - A/B comparison summary
- `oci-metrics-*.md` / `oci-metrics-*.html` - OCI metrics reports (if enabled)
