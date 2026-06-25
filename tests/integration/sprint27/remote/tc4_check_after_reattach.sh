set -u

CONSISTENT_DEV="${CONSISTENT_DEV:-/dev/oracleoci/oraclevdb}"
MNT=/mnt/s27clean

sudo mkdir -p "$MNT"
echo "--- TC4 discovery: block layout ---"
lsblk -o NAME,PATH,TYPE,SIZE,MODEL,WWN,FSTYPE,UUID,MOUNTPOINT 2>&1 || true
echo "--- TC4 discovery: blkid ---"
sudo blkid 2>&1 || true
echo "--- TC4 discovery: multipath -ll ---"
sudo multipath -ll 2>&1 || true
echo "--- TC4 discovery: multipathd paths ---"
sudo multipathd show paths 2>&1 || true
echo "--- TC4 discovery: oracleoci links ---"
ls -l /dev/oracleoci 2>&1 || true
echo "--- TC4 discovery: mapper links ---"
ls -l /dev/mapper 2>&1 || true
echo "--- TC4 discovery: requested consistent path resolution ---"
if [ -e "$CONSISTENT_DEV" ]; then
  echo "consistent_path_exists=true path=$CONSISTENT_DEV real=$(readlink -f "$CONSISTENT_DEV" 2>/dev/null || true)"
  ls -l "$CONSISTENT_DEV" 2>&1 || true
else
  echo "consistent_path_exists=false path=$CONSISTENT_DEV"
fi
for map in /dev/mapper/mpath*; do
  if [ -e "$map" ]; then
    echo "mapper_path=$map real=$(readlink -f "$map" 2>/dev/null || true)"
  fi
done

try_device() {
  dev="$1"
  [ -b "$dev" ] || return 1
  echo "--- TC4 discovery: candidate=$dev real=$(readlink -f "$dev" 2>/dev/null || echo unknown) ---"
  sudo blkid "$dev" 2>&1 || true
  fstype="$(sudo blkid -o value -s TYPE "$dev" 2>/dev/null || true)"
  if [ "$fstype" != "ext4" ]; then
    echo "candidate_skip_reason=not_ext4 fstype=${fstype:-none}"
    return 1
  fi
  sudo fsck.ext4 -fn "$dev" 2>&1 || return 1
  sudo mount -o ro "$dev" "$MNT" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    findmnt "$MNT" || true
    if [ -f "$MNT/stable.sha256" ]; then
      (cd "$MNT" && sha256sum -c stable.sha256)
      checksum_rc=$?
    else
      echo "stable.sha256 missing on $dev"
      checksum_rc=44
    fi
    sudo umount "$MNT" 2>&1 || true
    if [ "$checksum_rc" -eq 0 ]; then
      echo "tc4_discovered_device=$dev"
      echo "checksum_after_reattach=PASS"
      return 0
    fi
    return "$checksum_rc"
  fi
  return "$rc"
}

candidates=""
for dev in "$CONSISTENT_DEV" /dev/mapper/mpath* /dev/oracleoci/* /dev/disk/by-uuid/* /dev/dm-* /dev/sd*; do
  [ -e "$dev" ] && candidates="$candidates $dev"
done

seen=""
for dev in $candidates; do
  real="$(readlink -f "$dev" 2>/dev/null || echo "$dev")"
  case " $seen " in
    *" $real "*) continue ;;
  esac
  seen="$seen $real"
  if try_device "$dev"; then
    exit 0
  fi
done

echo "checksum_after_reattach=UNKNOWN"
echo "tc4_discovery_result=NO_CANDIDATE_DEVICE_MOUNTED_WITH_VALID_CHECKSUM"
exit 2
