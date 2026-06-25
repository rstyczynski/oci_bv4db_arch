set +e

CONSISTENT_DEV="${CONSISTENT_DEV:-/dev/oracleoci/oraclevdb}"
MNT=/mnt/s27unsafe

echo "--- TC3 filesystem check after unsafe detach/reattach ---"
echo "--- TC3 discovery: block layout ---"
lsblk -o NAME,PATH,TYPE,SIZE,MODEL,WWN,FSTYPE,UUID,MOUNTPOINT 2>&1 || true
echo "--- TC3 discovery: multipath -ll ---"
sudo multipath -ll 2>&1 || true
echo "--- TC3 discovery: requested consistent path resolution ---"
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

sudo mkdir -p "$MNT"
tc3_checksum_result=NO_EXT4_CANDIDATE_CHECKED
seen=""
for dev in "$CONSISTENT_DEV" /dev/mapper/mpath* /dev/oracleoci/* /dev/disk/by-uuid/* /dev/dm-* /dev/sd*; do
  [ -e "$dev" ] || continue
  real="$(readlink -f "$dev" 2>/dev/null || echo "$dev")"
  case " $seen " in
    *" $real "*) continue ;;
  esac
  seen="$seen $real"
  [ -b "$dev" ] || continue
  echo "--- TC3 discovery: candidate=$dev real=$real ---"
  fstype="$(sudo blkid -o value -s TYPE "$dev" 2>/dev/null || true)"
  echo "candidate_fstype=${fstype:-none}"
  [ "$fstype" = "ext4" ] || continue
  sudo fsck.ext4 -fn "$dev" 2>&1 || true
  sudo mount -o ro "$dev" "$MNT" 2>&1 || true
  if findmnt "$MNT" >/dev/null 2>&1; then
    findmnt "$MNT" || true
    if [ -f "$MNT/stable.sha256" ]; then
      (cd "$MNT" && sha256sum -c stable.sha256) 2>&1
      rc=$?
      if [ "$rc" -eq 0 ]; then
        tc3_checksum_result=PASS_NO_DATA_LOSS_OBSERVED_FOR_STABLE_FILE
      else
        tc3_checksum_result=FAIL_CHECKSUM_MISMATCH
      fi
    else
      tc3_checksum_result=FAIL_STABLE_CHECKSUM_FILE_MISSING
    fi
    ls -la "$MNT" 2>&1 || true
    sudo umount "$MNT" 2>&1 || true
    break
  fi
done
echo "tc3_checksum_result=$tc3_checksum_result"
