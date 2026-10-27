#!/usr/bin/env bash
# Seed the run's empty working directory with the tree that the case
# architect-stops-at-the-design-gate keeps under workspace/, write the change
# under review as change.diff, and put the changed files of this case's
# workspace/ on top. The diff is written here and not kept in the case,
# because the hook that trims trailing whitespace would break the blank
# context lines of a diff file.
set -euo pipefail

case_dir=$(dirname "${BASH_SOURCE[0]}")
cp -R "$case_dir/../architect-stops-at-the-design-gate/workspace/." .
status=0
diff -u --label a/rates/client.py --label b/rates/client.py \
  rates/client.py "$case_dir/workspace/rates/client.py" >change.diff || status=$?
if [[ $status -ne 1 ]]; then
  echo "seed-workspace: diff gave status $status, where 1 means a change to review" >&2
  exit 1
fi
cp -R "$case_dir/workspace/." .
