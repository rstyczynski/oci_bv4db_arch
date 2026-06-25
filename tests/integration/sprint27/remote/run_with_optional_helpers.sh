set -euo pipefail

env_file="${1:-}"
helper_file="${2:-}"
script_file="${3:?missing script file}"

if [ -n "$env_file" ]; then
  set -a
  # shellcheck disable=SC1090
  . "./$env_file"
  set +a
fi

if [ -n "$helper_file" ]; then
  # shellcheck disable=SC1090
  . "./$helper_file"
fi

# shellcheck disable=SC1090
. "./$script_file"
