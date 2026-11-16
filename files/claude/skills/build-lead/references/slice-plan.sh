#!/bin/bash
# Usage: slice-plan.sh PLAN OUT_DIR LANE NAME TASK_ID...
# Writes OUT_DIR/lane-LANE-NAME.md: plan header, Global Constraints, Review Focus,
# the lane's tasks (### Task ID: ... in the order given), Lanes, Plan rulings.
# Fails on a missing plan or any task heading not found.
set -euo pipefail

if [ "$#" -lt 5 ]; then
  echo "usage: ${0##*/} PLAN OUT_DIR LANE NAME TASK_ID..." >&2
  exit 2
fi
plan=$1; outdir=$2; lane=$3; name=$4; shift 4

[ -f "$plan" ] || { echo "error: plan not found: $plan" >&2; exit 1; }
mkdir -p "$outdir"
out="$outdir/lane-$lane-$name.md"
tmp=$(mktemp "$outdir/.slice.XXXXXX")
trap 'rm -f "$tmp"' EXIT

grep -q '^## Global Constraints' "$plan" || { echo "error: no '## Global Constraints' in $plan" >&2; exit 1; }

{
  # Header: everything before Global Constraints
  awk '/^## Global Constraints/{exit} {print}' "$plan"
  # Global Constraints and Review Focus: from Global Constraints up to ## Lanes
  awk '/^## Global Constraints/{p=1} /^## Lanes/{exit} p{print}' "$plan"
  # The lane's tasks, verbatim, in the order given
  for t in "$@"; do
    section=$(awk -v t="### Task $t:" '
      index($0,t)==1 {p=1; print; next}
      p && (/^### Task / || /^## /) {exit}
      p {print}' "$plan")
    [ -n "$section" ] || { echo "error: heading '### Task $t:' not found in $plan" >&2; exit 1; }
    printf '%s\n' "$section"
  done
  # Lanes: from ## Lanes up to the first ### Task heading after it
  awk '/^## Lanes/{p=1} p&&/^### Task /{exit} p{print}' "$plan"
  # Plan rulings to the end
  awk '/^## Plan rulings/{p=1} p{print}' "$plan"
} > "$tmp"

mv "$tmp" "$out"
trap - EXIT
echo "$out"
