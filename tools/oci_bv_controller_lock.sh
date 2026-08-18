#!/usr/bin/env bash
# Atomic controller-lifetime lock shared by fresh and resumed Sprint 30 runs.

BV_CONTROLLER_LOCK_DIR=""
BV_CONTROLLER_LOCK_HELD=false

bv_controller_lock_acquire() {
  local output_dir="$1" owner host pid stale
  local lock_dir="$output_dir/.controller.lock"
  host=$(hostname)
  if ! mkdir "$lock_dir" 2>/dev/null; then
    owner="$lock_dir/owner.json"
    [ -s "$owner" ] || { echo "controller lock exists without valid ownership evidence: $lock_dir" >&2; return 1; }
    pid=$(jq -r '.pid // empty' "$owner"); stale=$(jq -r '.hostname // empty' "$owner")
    [ "$stale" = "$host" ] || { echo "controller lock belongs to another host: $stale" >&2; return 1; }
    if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
      echo "another Sprint 30 controller is active with PID $pid" >&2
      return 1
    fi
    stale="$output_dir/controller_lock_stale_$(date -u +%Y%m%dT%H%M%SZ)_$$"
    mv "$lock_dir" "$stale" || return 1
    mkdir "$lock_dir" || return 1
  fi
  if ! jq -n --argjson pid "${BASHPID:-$$}" --arg hostname "$host" --arg started_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{pid:$pid,hostname:$hostname,started_at:$started_at}' > "$lock_dir/owner.json"; then
    rmdir "$lock_dir" 2>/dev/null || true
    return 1
  fi
  BV_CONTROLLER_LOCK_DIR="$lock_dir"
  BV_CONTROLLER_LOCK_HELD=true
}

bv_controller_lock_release() {
  [ "$BV_CONTROLLER_LOCK_HELD" = true ] || return 0
  rm -f "$BV_CONTROLLER_LOCK_DIR/owner.json"
  rmdir "$BV_CONTROLLER_LOCK_DIR"
  BV_CONTROLLER_LOCK_HELD=false
  BV_CONTROLLER_LOCK_DIR=""
}
