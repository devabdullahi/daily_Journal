#!/usr/bin/env bash
# Usage: bench.sh <easel-binary> <label> <runs> <width> <plan.lua>...
# Prints per-plan median/min/max wall seconds and the SHA-256 of the output PNG (for exactness checks).
set -euo pipefail
bin=$1; label=$2; runs=$3; width=$4; shift 4
out="${OUT:-$(mktemp -d)}"; mkdir -p "$out"
for plan in "$@"; do
  name=$(basename "$plan" .lua)
  times=()
  for i in $(seq 1 "$runs"); do
    s=$(python3 -c 'import time; print(time.time())')
    "$bin" run "$plan" --out "$out/$name.png" --width "$width" > /dev/null 2>&1
    e=$(python3 -c 'import time; print(time.time())')
    times+=("$(python3 -c "print(round($e-$s,2))")")
  done
  stats=$(printf '%s\n' "${times[@]}" | sort -n | python3 -c 'import sys,statistics as s; v=[float(x) for x in sys.stdin]; print(f"median={s.median(v):.2f}s min={min(v):.2f}s max={max(v):.2f}s")')
  hash=$(shasum -a 256 "$out/$name.png" | cut -c1-16)
  echo "$label $name w=$width runs=$runs $stats png=$hash"
done
[ -n "${OUT:-}" ] || rm -rf "$out"
