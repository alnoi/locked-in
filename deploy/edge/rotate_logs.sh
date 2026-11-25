#!/usr/bin/env bash
set -Eeuo pipefail
export PATH=/snap/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
exec 9>logs.lock
flock -n 9 || exit 0
rotated=false
for name in abuse error; do
  file="logs/$name.log"
  if [[ -f "$file" ]] && (( $(stat -c %s "$file") > 10485760 )); then
    [[ ! -f "$file.2" ]] || mv -f -- "$file.2" "$file.3"
    [[ ! -f "$file.1" ]] || mv -f -- "$file.1" "$file.2"
    mv -- "$file" "$file.1"
    rotated=true
  fi
done
if "$rotated"; then docker kill --signal=USR1 track-it-proxy >/dev/null; fi
