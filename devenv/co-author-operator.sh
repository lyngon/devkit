#!/usr/bin/env bash
set -euo pipefail

[[ -n ${LYNGON_AGENT_OPERATOR-} ]] || exit 0
git interpret-trailers --in-place --if-exists addIfDifferent \
  --trailer "Co-authored-by: $LYNGON_AGENT_OPERATOR" "$1"
