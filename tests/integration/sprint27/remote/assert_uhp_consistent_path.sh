set -u

CONSISTENT_DEV="${CONSISTENT_DEV:-/dev/oracleoci/oraclevdb}"

echo "--- consistent path validation: block layout ---"
lsblk -o NAME,PATH,TYPE,SIZE,MODEL,WWN,FSTYPE,UUID,MOUNTPOINT 2>&1 || true
echo "--- consistent path validation: oracleoci links ---"
ls -l /dev/oracleoci 2>&1 || true
echo "--- consistent path validation: mapper links ---"
ls -l /dev/mapper 2>&1 || true
echo "--- consistent path validation: multipath -ll ---"
sudo multipath -ll 2>&1 || true

if [ ! -e "$CONSISTENT_DEV" ]; then
  echo "consistent_path_exists=false path=$CONSISTENT_DEV"
  echo "consistent_path_result=FAIL_MISSING"
  exit 2
fi

real="$(readlink -f "$CONSISTENT_DEV" 2>/dev/null || true)"
echo "consistent_path_exists=true path=$CONSISTENT_DEV real=$real"
ls -l "$CONSISTENT_DEV" 2>&1 || true
if [ -z "$real" ] || [ ! -b "$real" ]; then
  echo "consistent_path_result=FAIL_NOT_BLOCK_DEVICE"
  exit 3
fi

matched_mapper=""
for map in /dev/mapper/mpath*; do
  [ -e "$map" ] || continue
  map_real="$(readlink -f "$map" 2>/dev/null || true)"
  echo "mapper_path=$map real=$map_real"
  if [ "$map_real" = "$real" ]; then
    matched_mapper="$map"
  fi
done

if [ -z "$matched_mapper" ]; then
  echo "consistent_path_result=FAIL_NOT_MULTIPATH_MAPPER"
  exit 4
fi

friendly_name="$(basename "$matched_mapper")"
echo "consistent_path_mapper=$matched_mapper"
echo "consistent_path_friendly_name=$friendly_name"
sudo multipath -ll "$friendly_name" 2>&1 || true
echo "consistent_path_result=PASS"
