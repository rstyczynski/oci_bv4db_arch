#!/usr/bin/env bash
#
# Sprint 20 guest-side load generator.
# Runs on the compute instance (OL8). Intended to be copied from laptop via scp
# and executed remotely (or run directly on the instance by an operator).
#
# Outputs:
# - fio: JSON to OUT_JSON
# - dd:  JSON summary to OUT_JSON and human log to OUT_TXT
#
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bv4db_sprint20_load.sh --mode auto|fio|dd --mnt <mountpoint> --out-json <path> [--out-txt <path>]

Fio parameters (optional):
  --fio-profile randrw_4k|read_1m_bw
  --fio-runtime-sec <sec>
  --fio-size-gb <gb>
  --fio-numjobs <n>
  --fio-iodepth <n>

Environment (optional):
  FIO_PROFILE       (default: randrw_4k)
  FIO_RUNTIME_SEC   (default: 120)
  FIO_SIZE_GB       (default: 16)   # file size for fio
  FIO_NUMJOBS       (default: 4)
  FIO_IODEPTH       (default: 32)
  FIO_STATUS_INTERVAL_SEC (default: 10)  # fio progress interval (stderr)

  DD_RUNTIME_SEC    (default: 0)    # timed mode if >0 (write for N sec, then read for N sec)
  DD_SIZE_GB        (default: 16)   # sized mode (per job) if DD_RUNTIME_SEC=0
  DD_JOBS           (default: 4)
  DD_BS             (default: 16M)

Notes:
  - Run as root (recommended) or via sudo.
  - Mountpoint must be writable.
EOF
}

MODE="auto"
MNT=""
OUT_JSON=""
OUT_TXT=""
FIO_PROFILE="${FIO_PROFILE:-randrw_4k}"

while [ $# -gt 0 ]; do
  case "$1" in
    --mode) MODE="${2:-}"; shift 2 ;;
    --mnt) MNT="${2:-}"; shift 2 ;;
    --out-json) OUT_JSON="${2:-}"; shift 2 ;;
    --out-txt) OUT_TXT="${2:-}"; shift 2 ;;
    --fio-profile) FIO_PROFILE="${2:-}"; shift 2 ;;
    --fio-runtime-sec) FIO_RUNTIME_SEC="${2:-}"; shift 2 ;;
    --fio-size-gb) FIO_SIZE_GB="${2:-}"; shift 2 ;;
    --fio-numjobs) FIO_NUMJOBS="${2:-}"; shift 2 ;;
    --fio-iodepth) FIO_IODEPTH="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

[ -n "$MNT" ] || { echo "Missing --mnt" >&2; exit 2; }
[ -n "$OUT_JSON" ] || { echo "Missing --out-json" >&2; exit 2; }

mkdir -p "$(dirname "$OUT_JSON")" || true
if [ -n "${OUT_TXT:-}" ]; then
  mkdir -p "$(dirname "$OUT_TXT")" || true
fi

touch "$OUT_JSON"
chmod 0644 "$OUT_JSON" 2>/dev/null || true
if [ -n "${OUT_TXT:-}" ]; then
  touch "$OUT_TXT"
  chmod 0644 "$OUT_TXT" 2>/dev/null || true
fi

run_fio() {
  local runtime="${FIO_RUNTIME_SEC:-120}"
  local size_gb="${FIO_SIZE_GB:-16}"
  local numjobs="${FIO_NUMJOBS:-4}"
  local iodepth="${FIO_IODEPTH:-32}"
  local profile="${FIO_PROFILE:-randrw_4k}"
  local status_interval="${FIO_STATUS_INTERVAL_SEC:-10}"

  command -v fio >/dev/null 2>&1 || { echo "fio not found" >&2; return 42; }

  local start_utc end_utc
  start_utc="$(date -u +%FT%TZ)"

  # Optional progress log file (also helps correlate with OCI metrics).
  if [ -n "${OUT_TXT:-}" ]; then
    : >"$OUT_TXT"
    chmod 0644 "$OUT_TXT" 2>/dev/null || true
    {
      echo "=== fio progress ==="
      echo "start_utc: $start_utc"
      echo "profile: $profile"
      echo "runtime_sec: $runtime"
      echo "numjobs: $numjobs"
      echo "iodepth: $iodepth"
      echo "status_interval_sec: $status_interval"
      echo
    } >>"$OUT_TXT"
  fi

  # Build the base fio args shared by all profiles.
  fio_base_args=(
    --time_based=1
    --runtime="$runtime"
    --numjobs="$numjobs"
    --iodepth="$iodepth"
    --ioengine=libaio
    --direct=1
    --group_reporting
    --status-interval="$status_interval"
    --eta=always
    --output="$OUT_JSON"
    --output-format=json
    --filename="$MNT/testfile"
  )

  case "$profile" in
    randrw_4k)
      fio \
        --name=randrw-4k \
        --rw=randrw \
        --rwmixread=70 \
        --bs=4k \
        --size="${size_gb}G" \
        "${fio_base_args[@]}" \
        > >(awk '{ ts=strftime("%Y-%m-%dT%H:%M:%SZ", systime()); print "[fio] " ts " " $0 }' | tee -a "${OUT_TXT:-/dev/null}" >&2) \
        2> >(awk '{ ts=strftime("%Y-%m-%dT%H:%M:%SZ", systime()); print "[fio] " ts " " $0 }' | tee -a "${OUT_TXT:-/dev/null}" >&2)
      ;;
    read_1m_bw)
      fio \
        --name=read-1m \
        --rw=read \
        --bs=1M \
        --size="${size_gb}G" \
        "${fio_base_args[@]}" \
        > >(awk '{ ts=strftime("%Y-%m-%dT%H:%M:%SZ", systime()); print "[fio] " ts " " $0 }' | tee -a "${OUT_TXT:-/dev/null}" >&2) \
        2> >(awk '{ ts=strftime("%Y-%m-%dT%H:%M:%SZ", systime()); print "[fio] " ts " " $0 }' | tee -a "${OUT_TXT:-/dev/null}" >&2)
      ;;
    *)
      echo "Invalid FIO profile: $profile (expected randrw_4k|read_1m_bw)" >&2
      return 2
      ;;
  esac

  end_utc="$(date -u +%FT%TZ)"

  test -s "$OUT_JSON"
  chmod 0644 "$OUT_JSON" || true

  # Inject correlation metadata into the fio JSON output.
  python3 - "$OUT_JSON" "$start_utc" "$end_utc" <<'PY'
import json
import sys

path, start_utc, end_utc = sys.argv[1:4]
raw = open(path, "r", encoding="utf-8").read()
# Some fio builds may append non-JSON to the output when status is enabled.
# Parse only the first JSON document and rewrite the file as clean JSON.
decoder = json.JSONDecoder()
data, _ = decoder.raw_decode(raw.lstrip())

meta = data.get("bv4db") or {}
meta.update({
    "start_time_utc": start_utc,
    "end_time_utc": end_utc,
})
data["bv4db"] = meta

with open(path, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2, sort_keys=True)
PY
}

run_dd() {
  local jobs="${DD_JOBS:-4}"
  local size_gb="${DD_SIZE_GB:-16}"     # per job
  local bs="${DD_BS:-16M}"
  local runtime_sec="${DD_RUNTIME_SEC:-0}"
  local progress_sec="${DD_PROGRESS_SEC:-10}"

  if [ -z "${OUT_TXT:-}" ]; then
    echo "dd mode requires --out-txt" >&2
    return 2
  fi

  : >"$OUT_JSON"
  : >"$OUT_TXT"
  chmod 0644 "$OUT_JSON" "$OUT_TXT" 2>/dev/null || true

  local count=$(( (size_gb * 1024) / 16 ))

  {
    echo "=== dd fallback workload ==="
    echo "date: $(date -u)"
    echo "mnt: $MNT"
    echo "jobs: $jobs"
    echo "bs: $bs"
    echo "progress_sec: $progress_sec"
    if [ "$runtime_sec" -gt 0 ] 2>/dev/null; then
      echo "mode: timed"
      echo "runtime_sec: $runtime_sec"
    else
      echo "mode: sized"
      echo "size_gb_per_job: $size_gb"
      echo "count(16MiB blocks): $count"
    fi
    echo
  } >>"$OUT_TXT"

  logp() {
    # Progress goes to both console (stderr) and OUT_TXT.
    # shellcheck disable=SC2059
    printf "[dd] %s\n" "$*" | tee -a "$OUT_TXT" >&2
  }

  if [ "$progress_sec" -le 0 ] 2>/dev/null; then progress_sec=10; fi
  logp "starting (mode=$([ "$runtime_sec" -gt 0 ] 2>/dev/null && echo timed || echo sized), jobs=$jobs, bs=$bs)"

  local w_start w_end r_start r_end
  w_start=$(date +%s)
  if [ "$runtime_sec" -gt 0 ] 2>/dev/null; then
    deadline=$((w_start + runtime_sec))
    i=0
    while [ "$(date +%s)" -lt "$deadline" ]; do
      i=$((i + 1))
      logp "write pass $i begin (elapsed=$(( $(date +%s) - w_start ))s)"
      for j in $(seq 1 "$jobs"); do
        # status=progress is best-effort (GNU dd). If unsupported, dd will error; so we try and fall back.
        (dd if=/dev/zero of="$MNT/ddfile_${j}.bin" bs="$bs" oflag=direct conv=fsync status=progress 2>>"$OUT_TXT" || \
         dd if=/dev/zero of="$MNT/ddfile_${j}.bin" bs="$bs" oflag=direct conv=fsync status=none) &
      done
      wait
      logp "write pass $i done (utc=$(date -u))"
    done
  else
    logp "write begin (sized)"
    for j in $(seq 1 "$jobs"); do
      (dd if=/dev/zero of="$MNT/ddfile_${j}.bin" bs="$bs" count="$count" oflag=direct conv=fsync status=progress 2>>"$OUT_TXT" || \
       dd if=/dev/zero of="$MNT/ddfile_${j}.bin" bs="$bs" count="$count" oflag=direct conv=fsync status=none) &
    done
    wait
  fi
  w_end=$(date +%s)
  logp "write done (write_sec=$((w_end - w_start)))"

  r_start=$(date +%s)
  if [ "$runtime_sec" -gt 0 ] 2>/dev/null; then
    deadline=$((r_start + runtime_sec))
    i=0
    while [ "$(date +%s)" -lt "$deadline" ]; do
      i=$((i + 1))
      logp "read pass $i begin (elapsed=$(( $(date +%s) - r_start ))s)"
      for j in $(seq 1 "$jobs"); do
        (dd if="$MNT/ddfile_${j}.bin" of=/dev/null bs="$bs" iflag=direct status=progress 2>>"$OUT_TXT" || \
         dd if="$MNT/ddfile_${j}.bin" of=/dev/null bs="$bs" iflag=direct status=none) &
      done
      wait
      logp "read pass $i done (utc=$(date -u))"
    done
  else
    logp "read begin (sized)"
    for j in $(seq 1 "$jobs"); do
      (dd if="$MNT/ddfile_${j}.bin" of=/dev/null bs="$bs" iflag=direct status=progress 2>>"$OUT_TXT" || \
       dd if="$MNT/ddfile_${j}.bin" of=/dev/null bs="$bs" iflag=direct status=none) &
    done
    wait
  fi
  r_end=$(date +%s)
  logp "read done (read_sec=$((r_end - r_start)))"

  local write_sec=$((w_end - w_start))
  local read_sec=$((r_end - r_start))
  [ "$write_sec" -gt 0 ] || write_sec=1
  [ "$read_sec" -gt 0 ] || read_sec=1

  # Approx bytes moved. In timed mode, we approximate from file sizes after write.
  local bytes_written=0
  if [ "$runtime_sec" -gt 0 ] 2>/dev/null; then
    for j in $(seq 1 "$jobs"); do
      sz=$(stat -c '%s' "$MNT/ddfile_${j}.bin" 2>/dev/null || echo 0)
      bytes_written=$((bytes_written + sz))
    done
  else
    bytes_written=$((jobs * size_gb * 1024 * 1024 * 1024))
  fi
  local bytes_read="$bytes_written"

  python3 - <<PY >"$OUT_JSON"
import json
bytes_written=int(${bytes_written})
bytes_read=int(${bytes_read})
write_sec=max(int(${write_sec}), 1)
read_sec=max(int(${read_sec}), 1)
write_mbps=bytes_written/(write_sec*1024*1024)
read_mbps=bytes_read/(read_sec*1024*1024)
payload={
  "generator": "dd",
  "jobs": int(${jobs}),
  "bs": "${bs}",
  "mode": "timed" if int(${runtime_sec}) > 0 else "sized",
  "runtime_sec": int(${runtime_sec}),
  "size_gb_per_job": int(${size_gb}),
  "write_mbps": float(f"{write_mbps:.2f}"),
  "read_mbps": float(f"{read_mbps:.2f}"),
  "total_mbps": float(f"{(write_mbps+read_mbps):.2f}"),
  "write_sec": int(${write_sec}),
  "read_sec": int(${read_sec}),
  "bytes_written": bytes_written,
  "bytes_read": bytes_read,
}
print(json.dumps(payload, indent=2, sort_keys=True))
PY

  chmod 0644 "$OUT_JSON" "$OUT_TXT" || true
  test -s "$OUT_JSON"
  test -s "$OUT_TXT"
}

case "$MODE" in
  auto)
    if run_fio; then exit 0; fi
    run_dd
    ;;
  fio)
    run_fio
    ;;
  dd)
    run_dd
    ;;
  *)
    echo "Invalid --mode: $MODE" >&2
    usage
    exit 2
    ;;
esac

